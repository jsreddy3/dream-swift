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

    public var uploads: AsyncStream<UploadResult> { stream }

    public init(baseURL: URL,
                session: URLSession = .shared) {
        self.base = baseURL
        self.session = session
        var c: AsyncStream<UploadResult>.Continuation!
        self.stream = AsyncStream { c = $0 }
        self.continuation = c
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: – DreamStore entry-points

    public func insertNew(_ dream: Dream) async throws {
        struct Payload: Encodable { let id: UUID; let title: String }
        let req = try makeRequest(
            path: "dreams/",
            method: "POST",
            json: Payload(id: dream.id, title: dream.title)
        )
        try await perform(req)
    }

    public func appendSegment(
        dreamID: UUID,
        segment: AudioSegment
    ) async throws {

        // optimistic update happens in the caller’s layer;
        // we just schedule the slow part and return.
        let path = try localPath(for: segment.filename)

        Task.detached(priority: .utility) { [weak self] in
            await self?._uploadAndRegister(dreamID, segment, path)
        }
    }

    public func removeSegment(
        dreamID: UUID,
        segmentID: UUID
    ) async throws {
        let req = try makeRequest(
            path: "dreams/\(dreamID)/segments/\(segmentID)",
            method: "DELETE"
        )
        try await perform(req)
    }

    public func segments(dreamID: UUID) async throws -> [AudioSegment] {
        let req = try makeRequest(
            path: "dreams/\(dreamID)/segments/",
            method: "GET"
        )
        return try await decode([AudioSegment].self, from: req)
    }
    
    public func getTranscript(dreamID: UUID) async throws -> String? {
        let req = try makeRequest(
            path: "dreams/\(dreamID)/transcript/",
            method: "GET"
        )
        let transcript = try await performReturningTranscript(req)
        return transcript
    }

    public func markCompleted(_ dreamID: UUID) async throws {
        let req = try makeRequest(
            path: "dreams/\(dreamID)/finish",
            method: "POST"
        )
        try await perform(req)
    }

    public func allDreams() async throws -> [Dream] {
        let req = try makeRequest(path: "list-dreams/", method: "GET")
        let all_dreams = try await decode([Dream].self, from: req)
        return all_dreams
    }

    public func updateTitle(
        dreamID: UUID,
        title: String
    ) async throws {
        struct Payload: Encodable { let title: String }
        let req = try makeRequest(
            path: "dreams/\(dreamID)",
            method: "PATCH",
            json: Payload(title: title)
        )
        try await perform(req)
    }

    // MARK: – Helpers (small, focused)
    
    private func _uploadAndRegister(
        _ dreamID: UUID,
        _ segment: AudioSegment,
        _ path: URL
    ) async {

        do {
            let signed = try await fetchUploadURL(dreamID, segment.filename)
            try await upload(local: path, to: signed.url)

            let payload = RegisterPayload(
                segment_id: segment.id,
                filename: segment.filename,
                duration: segment.duration,
                order: segment.order,
                s3_key: signed.s3Key
            )
            let req = try makeRequest(
                        path: "/dreams/\(dreamID)/segments/",
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
            // In a real app you’d store a retry ticket or emit a Notification
            // so the UI can surface “Upload failed – tap to retry”.
            // For now we just log.
            NSLog("Segment upload failed: \(error)")
        }
    }

    private struct Presigned: Decodable { let upload_url: URL; let s3_key: String }
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
        comps.path   = "/dreams/\(id)/upload-url/"       // ← no leading /
        comps.queryItems = [.init(name: "filename", value: filename)]

        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"                         // ← make it POST
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse,
              200..<300 ~= http.statusCode else {
            throw RemoteError.badStatus(
                (resp as? HTTPURLResponse)?.statusCode ?? -1,
                String(data: data, encoding: .utf8) ?? ""
            )
        }

        let presigned = try decoder.decode(Presigned.self, from: data)
        return (presigned.upload_url, presigned.s3_key)
    }

    private func upload(local path: URL, to presigned: URL) async throws {
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw RemoteError.io(
                NSError(domain: "LocalFile", code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "Missing clip on disk"])
            )
        }
        var req = URLRequest(url: presigned)
        req.httpMethod = "PUT"
        req.httpBody = try Data(contentsOf: path)
        req.setValue("audio/mpeg", forHTTPHeaderField: "Content-Type")
        let (_, resp) = try await session.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw RemoteError.badStatus(
                (resp as? HTTPURLResponse)?.statusCode ?? -1, ""
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
    
    private func makeRequest(
        path: String,
        method: String
    ) throws -> URLRequest {
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = method
        return req
    }

    private func makeRequest<T: Encodable>(
        path: String,
        method: String,
        json: T? = nil
    ) throws -> URLRequest {
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = method
        if let body = json {
            req.httpBody = try encoder.encode(body)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return req
    }

    private func perform(_ req: URLRequest) async throws {
        let (_, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw RemoteError.badStatus(-1, "")
        }
        guard 200..<300 ~= http.statusCode else {
            throw RemoteError.badStatus(http.statusCode, "")
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

        // The server’s schema for AudioSegmentRead looks like:
        // { "id": "...", "filename": "...", "duration": 10.0,
        //   "order": 0, "transcript": "hello there" }
        // We only need the last part, so decode into a tiny throw-away struct.
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
