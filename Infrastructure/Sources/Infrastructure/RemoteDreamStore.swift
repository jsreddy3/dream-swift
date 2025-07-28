//
//  RemoteDreamStore.swift
//  Infrastructure
//
//  Created by DreamFinder.
//

import Foundation
import DomainLogic
import CoreModels

public enum RemoteError: Error, LocalizedError, Sendable {
    case notFound
    case badStatus(Int, String)
    case io(Error)

    public var errorDescription: String? {
        switch self {
        case .notFound:              "Resource not found on server."
        case .badStatus(let c, _):   "Server returned HTTP \(c)."
        case .io(let e):             e.localizedDescription
        }
    }
}

public actor RemoteDreamStore: DreamStore, Sendable {

    // MARK: – Init

    private let base: URL
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let stream: AsyncStream<UploadResult>
    private let continuation: AsyncStream<UploadResult>.Continuation
    private let auth: AuthStore

    public var uploads: AsyncStream<UploadResult> { stream }
    private var activeStreams: [UUID: Task<(), Never>] = [:]

    public init(baseURL: URL,
                session: URLSession = .shared,
                auth: AuthStore) {
        self.base = baseURL
        self.session = session
        self.auth = auth
        var c: AsyncStream<UploadResult>.Continuation!
        self.stream = AsyncStream { c = $0 }
        self.continuation = c
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: – DreamStore entry-points

    public func insertNew(_ dream: Dream) async throws {
        struct Payload: Encodable {
            let id: UUID
            let title: String
            let created_at: Date
        }
        let req = try await makeRequest(
            path: "dreams/",
            method: "POST",
            json: Payload(id: dream.id,
                          title: dream.title,
                          created_at: dream.created_at)
        )
        try await perform(req)
    }

    public func appendSegment(
        dreamID: UUID,
        segment: Segment
    ) async throws {
        
        switch segment.modality {
            // ---------- AUDIO: upload file, then register ----------
            case .audio:
                guard
                    let name = segment.filename,
                    let path = try? localPath(for: name)
                else { throw RemoteError.io(NSError(domain: "LocalFile",
                                                    code: 0,
                                                    userInfo: [NSLocalizedDescriptionKey:
                                                        "Missing filename for audio segment"])) }

                Task.detached(priority: .utility) { [weak self] in
                    await self?._uploadAudioAndRegister(dreamID, segment, path)
                }

            // ---------- TEXT: one-shot register, no file ----------
            case .text:
                struct Payload: Encodable {
                    let segment_id: UUID
                    let order: Int
                    let modality = "text"
                    let text: String
                }
                let body = Payload(segment_id: segment.id,
                                   order: segment.order,
                                   text: segment.text ?? "")
                let req = try await makeRequest(
                    path: "dreams/\(dreamID)/segments",
                    method: "POST",
                    json: body
                )

                // server echoes transcript immediately
                let transcript = try await performReturningTranscript(req)
                continuation.yield(
                    .init(dreamID: dreamID,
                          segmentID: segment.id,
                          transcript: transcript)
                )
            }
    }


    public func removeSegment(
        dreamID: UUID,
        segmentID: UUID
    ) async throws {
        let req = try await makeRequest(
            path: "dreams/\(dreamID)/segments/\(segmentID)",
            method: "DELETE"
        )
        try await perform(req)
    }

    public func segments(dreamID: UUID) async throws -> [Segment] {
        let req = try await makeRequest(
            path: "dreams/\(dreamID)/segments",
            method: "GET"
        )
        return try await decode([Segment].self, from: req)
    }
    
    public func getTranscript(dreamID: UUID) async throws -> String? {
        let req = try await makeRequest(
            path: "dreams/\(dreamID)/transcript",
            method: "GET"
        )
        let transcript = try await performReturningTranscript(req)
        return transcript
    }

    public func markCompleted(_ dreamID: UUID) async throws {
        let req = try await makeRequest(
            path: "dreams/\(dreamID)/finish",
            method: "POST"
        )
        try await perform(req)
    }
    
    public func deleteDream(_ id: UUID) async throws {
        let req = try await makeRequest(
            path: "dreams/\(id)",
            method: "DELETE"
        )
        try await perform(req)
    }

    public func allDreams() async throws -> [Dream] {
        let req = try await makeRequest(path: "dreams/", method: "GET")
        
        let (data, _) = try await session.data(for: req)
        
        do {
            let all_dreams = try decoder.decode([Dream].self, from: data)
            return all_dreams
        } catch {
            // Try to decode what we can
            if let json = try? JSONSerialization.jsonObject(with: data, options: []) {
                print("Raw JSON: \(json)")
            }
            throw error
        }
    }

    public func updateTitle(
        dreamID: UUID,
        title: String
    ) async throws {
        struct Payload: Encodable { let title: String }
        let req = try await makeRequest(
            path: "dreams/\(dreamID)",
            method: "PATCH",
            json: Payload(title: title)
        )
        try await perform(req)
    }

    public func updateSummary(
        dreamID: UUID,
        summary: String
    ) async throws {
        struct Payload: Encodable { let summary: String }
        let req = try await makeRequest(
            path: "dreams/\(dreamID)",
            method: "PATCH",
            json: Payload(summary: summary)
        )
        try await perform(req)
    }

    public func updateTitleAndSummary(
        dreamID: UUID,
        title: String,
        summary: String
    ) async throws {
        struct Payload: Encodable { 
            let title: String
            let summary: String 
        }
        let req = try await makeRequest(
            path: "dreams/\(dreamID)",
            method: "PATCH",
            json: Payload(title: title, summary: summary)
        )
        try await perform(req)
    }
    
    // GET /dreams/{id}
    public func getDream(_ id: UUID) async throws -> Dream {
        print("DEBUG: RemoteDreamStore.getDream called for id: \(id)")
        let req = try await makeRequest(
            path: "dreams/\(id)",
            method: "GET"
        )
        print("DEBUG: About to make GET request to: \(req.url?.absoluteString ?? "no url")")
        let (data, _) = try await session.data(for: req)
        
        // Debug: print raw JSON
        if let jsonString = String(data: data, encoding: .utf8) {
            // Print first 500 chars to avoid flooding console
            let preview = String(jsonString.prefix(500))
            print("DEBUG: Raw JSON response preview: \(preview)...")
            
            // Check if analysis field exists in JSON
            if let jsonData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let hasAnalysis = jsonData["analysis"] != nil
                print("DEBUG: JSON contains 'analysis' field: \(hasAnalysis)")
                if hasAnalysis, let analysisValue = jsonData["analysis"] {
                    print("DEBUG: Analysis type: \(type(of: analysisValue)), is NSNull: \(analysisValue is NSNull)")
                }
            }
        }
        
        let dream = try decoder.decode(Dream.self, from: data)
        print("DEBUG: Decoded dream - has analysis: \(dream.analysis != nil)")
        return dream
    }

    // POST /dreams/{id}/generate-analysis
    public func requestAnalysis(_ id: UUID) async throws {
        print("DEBUG: RemoteDreamStore.requestAnalysis called for id: \(id)")
        do {
            let req = try await makeRequest(
                path: "dreams/\(id)/generate-analysis",
                method: "POST",
                json: ["force_regenerate": false]
            )
            print("DEBUG: Request created: \(req.url?.absoluteString ?? "no url")")
            print("DEBUG: About to perform request...")
            try await perform(req)
            print("DEBUG: Request completed successfully")
        } catch {
            print("DEBUG: requestAnalysis error: \(error)")
            throw error
        }
    }
    
    public func generateSummary(for id: UUID) async throws -> String {
        let req = try await makeRequest(
            path: "dreams/\(id)/generate-summary",
            method: "POST"
        )
        
        struct Envelope: Decodable { 
            let title: String
            let summary: String 
        }
        let result = try await decode(Envelope.self, from: req)
        
        // Since this is called by DreamStore protocol which expects just summary,
        // we need to update the title separately
        // This is a workaround - ideally the protocol should return both
        return result.summary
    }
    
    // MARK - SSE
    /// Opens (or re-opens) the server-sent-events pipe for one dream.
    private func ensureSSE(for did: UUID) {
        guard activeStreams[did] == nil else { return }        // already running

        let url = base
            .appendingPathComponent("dreams")
            .appendingPathComponent(did.uuidString)
            .appendingPathComponent("stream")

        let task = Task.detached(priority: .utility) { [weak self] in
            // hop out if the store vanishes while the task is still alive
            guard let self else { return }

            do {
                let (bytes, _) = try await self.session.bytes(from: url)

                for try await line in bytes.lines {
                    guard line.hasPrefix("data: ") else { continue }

                    let payload = line.dropFirst(6)                    // strip "data: "
                    if let data = payload.data(using: .utf8),
                       let evt = try? self.decoder.decode(StreamEvent.self, from: data),
                       !evt.transcript.isEmpty {

                        await self.continuation.yield(
                            .init(dreamID: did,
                                  segmentID: evt.segment_id,
                                  transcript: evt.transcript))
                    }
                }
            } catch {
                // network closed or server hung up — silently drop the stream
            }
        }

        activeStreams[did] = task
    }


    private func cancelSSE(for did: UUID) {
        activeStreams.removeValue(forKey: did)?.cancel()
    }
        
    public func getVideoURL(dreamID: UUID) async throws -> URL? {
        let req = try await makeRequest(
            path: "dreams/\(dreamID)/video-url/",
            method: "GET"
        )
        
        struct VideoURLResponse: Decodable {
            let video_url: URL
            let expires_in: Int
        }
        
        do {
            let response = try await decode(VideoURLResponse.self, from: req)
            return response.video_url
        } catch RemoteError.notFound {
            return nil
        } catch RemoteError.badStatus(404, _) {
            return nil
        }
    }
    
    private func _uploadAudioAndRegister(
        _ dreamID: UUID,
        _ segment: Segment,
        _ path: URL
    ) async {

        do {
            let signed = try await fetchUploadURL(dreamID, segment.filename!)
            try await upload(local: path, to: signed.url)

            struct RegisterPayload: Encodable {
                let segment_id: UUID
                let order: Int
                let modality = "audio"
                let filename: String
                let duration: TimeInterval
                let s3_key: String
            }

            let payload = RegisterPayload(
                segment_id: segment.id,
                order: segment.order,
                filename: segment.filename!,
                duration: segment.duration ?? 0,
                s3_key: signed.s3Key
            )
            
            let req = try await makeRequest(
                path: "dreams/\(dreamID)/segments",
                method: "POST",
                json: payload
            )
            let transcript = try await performReturningTranscript(req)

            continuation.yield(
                .init(dreamID: dreamID,
                      segmentID: segment.id,
                      transcript: transcript)
            )
        } catch {
            NSLog("Segment upload failed: \(error)")
        }
    }


    // MARK: – Helpers (small, focused)

    private struct Presigned: Decodable { let upload_url: URL; let upload_key: String }
    private struct RegisterPayload: Encodable {
        let segment_id: UUID
        let filename: String
        let duration: TimeInterval
        let order: Int
        let s3_key: String
    }

    private func fetchUploadURL(
        _ id: UUID,
        _ filename: String
    ) async throws -> (url: URL, s3Key: String) {

        var comps = URLComponents()
        comps.scheme = base.scheme
        comps.host   = base.host
        comps.port   = base.port
        comps.path   = "/dreams/\(id)/upload-url"       // ← no leading /
        comps.queryItems = [.init(name: "filename", value: filename)]

        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        if let token = try await auth.validJWT() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse,
              200..<300 ~= http.statusCode else {
            throw RemoteError.badStatus(
                (resp as? HTTPURLResponse)?.statusCode ?? -1,
                String(data: data, encoding: .utf8) ?? ""
            )
        }

        let presigned = try decoder.decode(Presigned.self, from: data)
        return (presigned.upload_url, presigned.upload_key)
    }

    private func upload(local path: URL, to presigned: URL) async throws {
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw RemoteError.io(
                NSError(domain: "LocalFile", code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "Missing clip on disk"])
            )
        }

        var req = URLRequest(url: presigned)
        req.httpMethod  = "PUT"
        req.httpBody    = try Data(contentsOf: path)

        // (Optional) Strip automatic headers that can break the signature.
        req.setValue("", forHTTPHeaderField: "Expect")

        let (data, resp) = try await session.data(for: req)

        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "<no body>"
            NSLog("S3 PUT failed \( (resp as? HTTPURLResponse)?.statusCode ?? -1 ): \(body)")
            throw RemoteError.badStatus(
                (resp as? HTTPURLResponse)?.statusCode ?? -1,
                body                                // ← preserve the body text
            )
        }
    }


    private func localPath(for filename: String) -> URL {
        let root = FileManager.default
            .urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Dreams", isDirectory: true)

        // The folder already exists because FileDreamStore created it.
        return root.appendingPathComponent(filename)
    }

    // MARK: – Networking mini-primitives
    
    // 1. No-body version
    private func makeRequest(
        path: String,
        method: String
    ) async throws -> URLRequest {
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = method

        if let token = try await auth.validJWT() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    // 2. JSON-body overload
    private func makeRequest<T: Encodable>(
        path: String,
        method: String,
        json: T? = nil
    ) async throws -> URLRequest {              // ← async, not “await func”
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = method
        if let body = json {
            req.httpBody = try encoder.encode(body)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let token = try await auth.validJWT() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }


    private func perform(_ req: URLRequest) async throws {
        let (data, resp) = try await session.data(for: req)

        if let http = resp as? HTTPURLResponse {
            switch http.statusCode {
            case 200..<300:                       // success → just return
                return
            case 404 where req.url?.path.hasSuffix("/finish") == true:
                // Swallow “already finished / unknown ID”
                print("Finish ignored: server doesn’t know this dream (404).")
                return
            default:
                throw RemoteError.badStatus(http.statusCode, "")
            }
        }
    }
    
    private func performReturningTranscript(_ req: URLRequest) async throws -> String {
        let (data, resp) = try await session.data(for: req)

        guard let http = resp as? HTTPURLResponse,
              200..<300 ~= http.statusCode else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? ""
            throw RemoteError.badStatus(code, body)
        }

        struct Envelope: Decodable { let transcript: String? }
        let env = try decoder.decode(Envelope.self, from: data)

        return env.transcript?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func decode<R: Decodable>(
        _ type: R.Type,
        from req: URLRequest
    ) async throws -> R {
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse,
              200..<300 ~= http.statusCode else {
            throw RemoteError.badStatus(
                (resp as? HTTPURLResponse)?.statusCode ?? -1,
                String(data: data, encoding: .utf8) ?? ""
            )
        }
        return try decoder.decode(R.self, from: data)
    }
}

public struct UploadResult: Sendable {
    public let dreamID: UUID
    public let segmentID: UUID
    public let transcript: String        // empty if Deepgram gave nothing
}

private struct StreamEvent: Decodable {
    let segment_id: UUID           // matches JSON field names
    let transcript: String
}
