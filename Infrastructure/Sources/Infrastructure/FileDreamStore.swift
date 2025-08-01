//
//  FileDreamStore.swift
//  Infrastructure
//
//  Updated for unified `Segment` type (audio / text)
//

import Foundation
import DomainLogic         // Dream, Segment, DreamState & DreamStore
import CoreModels

/// Errors that can surface while persisting dreams to disk.
public enum DreamStoreError: Error, LocalizedError, Sendable {
    case dreamNotFound(UUID)
    case segmentNotFound(UUID)
    case io(Error)
    case notSupported

    public var errorDescription: String? {
        switch self {
        case .dreamNotFound(let id):    "Dream \(id) could not be located on disk."
        case .segmentNotFound(let id):  "Segment \(id) is no longer present."
        case .io(let e):                e.localizedDescription
        case .notSupported:             "This operation is not supported offline."
        }
    }
}

#if DEBUG            // compiled only for test targets
extension FileDreamStore {
    /// Load a dream from disk so tests can assert on the persisted value.
    func debug_read(_ id: UUID) async throws -> Dream {
        try await read(id)
    }
}
#endif

/// JSON-backed implementation of DreamStore.
/// Every dream is stored as <ID>.json in the ~/Library/Dreams directory.
public actor FileDreamStore: DreamStore, Sendable {
    // MARK: – Init

    private let root: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Production entry-point — uses Library/ on device or simulator.
    public init(container: FileManager.SearchPathDirectory = .libraryDirectory) {
        let base = FileManager.default.urls(for: container, in: .userDomainMask)[0]
        self.root = base.appendingPathComponent("Dreams", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    /// **Test-only** entry-point — lets XCTest write to a throw-away folder.
    public init(customRootURL url: URL) {
        self.root = url.appendingPathComponent("Dreams", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: – DreamStore API

    public func insertNew(_ dream: Dream) async throws {
        try await write(dream)
    }

    public func appendSegment(dreamID: UUID, segment: Segment) async throws {
        var dream = try await read(dreamID)
        dream.segments.append(segment)
        try await write(dream)
    }

    public func markCompleted(_ dreamID: UUID) async throws -> Dream {
        var dream = try await read(dreamID)
        guard dream.state == .draft else { return dream }          // idempotent
        dream.state = .completed
        try await write(dream)
        return dream
    }
    
    public func deleteDream(_ id: UUID) async throws {
        let url = root.appendingPathComponent("\(id).json")
        try FileManager.default.removeItem(at: url)
    }
    
    public func generateImage(for id: UUID) async throws -> Dream {
        // FileDreamStore doesn't support image generation (offline)
        throw DreamStoreError.notSupported
    }

    public func segments(dreamID: UUID) async throws -> [Segment] {
        try await read(dreamID).segments
    }

    public func removeSegment(dreamID: UUID, segmentID: UUID) async throws {
        var dream = try await read(dreamID)
        let original = dream.segments.count
        dream.segments.removeAll { $0.id == segmentID }

        guard dream.segments.count < original else {
            throw DreamStoreError.segmentNotFound(segmentID)
        }
        try await write(dream)
    }

    public func upsertSegment(_ seg: Segment, dreamID: UUID) async throws {
        var dream = try await read(dreamID)
        if let i = dream.segments.firstIndex(where: { $0.id == seg.id }) {
            dream.segments[i] = seg
        } else {
            dream.segments.append(seg)
        }
        try await write(dream)
    }

    public func allDreams() async throws -> [Dream] {
        let files = try FileManager.default.contentsOfDirectory(at: root,
                            includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }

        var dreams: [Dream] = []
        for url in files {
            if let d = try? decoder.decode(Dream.self, from: Data(contentsOf: url)) {
                dreams.append(d)
            }
        }
        dreams.sort { $0.created_at > $1.created_at }
        return dreams
    }

    public func updateTitle(dreamID: UUID, title: String) async throws {
        var dream = try await read(dreamID)
        dream.title = title
        try await write(dream)
    }

    public func updateSummary(dreamID: UUID, summary: String) async throws {
        var dream = try await read(dreamID)
        dream.summary = summary
        try await write(dream)
    }

    public func updateTitleAndSummary(dreamID: UUID, title: String, summary: String) async throws {
        var dream = try await read(dreamID)
        dream.title = title
        dream.summary = summary
        try await write(dream)
    }

    public func getTranscript(dreamID: UUID) async throws -> String? {
        try await read(dreamID).transcript
    }

    public func getVideoURL(dreamID: UUID) async throws -> URL? {
        // File store doesn’t handle video URLs.
        return nil
    }
    
    public func getDream(_ id: UUID) async throws -> Dream {
        try await read(id)                 // fast local read
    }
    
    public func generateSummary(for id: UUID) async throws -> String {
        // 1️⃣ read what we have
        var dream = try await read(id)
        
        // 2️⃣ fallback: use transcript (if any) or ""
        let summary = dream.transcript ?? ""
        guard dream.summary == nil else { return dream.summary! }   // already summarised
        
        dream.summary = summary
        try await write(dream)        // persist so UI sees it
        return summary
    }
    
    public func requestAnalysis(for id: UUID, type: AnalysisType? = nil) async throws {
        // FileDreamStore can't perform analysis (offline)
        throw DreamStoreError.notSupported
    }
    
    public func requestExpandedAnalysis(for id: UUID) async throws {
        // FileDreamStore can't perform expanded analysis (offline)
        throw DreamStoreError.notSupported
    }
    
    public func generateSummaryFallback(id: UUID, text: String) async throws {
        try await updateDream(id) { $0.summary = text }
    }

    internal func replaceSegments(_ id: UUID, with segments: [Segment]) async throws {
        var dream = try await read(id)
        dream.segments = segments
        try await write(dream)
    }

    internal func upsert(_ dream: Dream) async throws {
        try await write(dream)
    }

    internal func updateDream(_ id: UUID,
                              mutating body: (inout Dream) -> Void) async throws {
        var dream = try await read(id)
        body(&dream)
        try await write(dream)
    }
    
    // MARK: – Helpers

    private func url(for id: UUID) -> URL {
        root.appendingPathComponent(id.uuidString).appendingPathExtension("json")
    }

    private func read(_ id: UUID) async throws -> Dream {
        let fileURL = url(for: id)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw DreamStoreError.dreamNotFound(id)
        }
        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(Dream.self, from: data)
        } catch {
            throw DreamStoreError.io(error)
        }
    }

    private func write(_ dream: Dream) async throws {
        let data: Data
        do {
            data = try encoder.encode(dream)
        } catch {
            throw DreamStoreError.io(error)
        }

        let fileURL = url(for: dream.id)
        do {
            let tmpURL = fileURL.appendingPathExtension("tmp")
            try data.write(to: tmpURL, options: .atomic)
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tmpURL)
        } catch {
            throw DreamStoreError.io(error)
        }
    }
}
