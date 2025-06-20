//
//  FileDreamStore.swift
//  Infrastructure
//
//  Created by DreamFinder.
//

import Foundation
import DomainLogic         // gives us Dream, AudioSegment, DreamState & DreamStore
import CoreModels

/// Errors that can surface while persisting dreams to disk.
public enum DreamStoreError: Error, LocalizedError, Sendable {
    case dreamNotFound(UUID)
    case segmentNotFound(UUID)       // ← new
    case io(Error)

    public var errorDescription: String? {
        switch self {
        case .dreamNotFound(let id):    "Dream \(id) could not be located on disk."
        case .segmentNotFound(let id):  "Segment \(id) is no longer present."
        case .io(let e):                e.localizedDescription
        }
    }
}

#if DEBUG            // compiled only for test targets
extension FileDreamStore {
    /// Load a dream from disk so tests can assert on the persisted value.
    func debug_read(_ id: UUID) async throws -> Dream {
        try await read(id)                // calls the actor’s private method
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

    // MARK: – DreamStore

    public func insertNew(_ dream: Dream) async throws {
        try await write(dream)
    }

    public func appendSegment(dreamID: UUID, segment: AudioSegment) async throws {
        var dream = try await read(dreamID)
        dream.segments.append(segment)
        try await write(dream)
    }

    public func markCompleted(_ dreamID: UUID) async throws {
        var dream = try await read(dreamID)
        guard dream.state == .draft else { return }          // idempotent
        dream.state = .completed
        try await write(dream)
    }
    
    public func segments(dreamID: UUID) async throws -> [AudioSegment] {
            try await read(dreamID).segments
        }

    public func removeSegment(dreamID: UUID, segmentID: UUID) async throws {
        var dream = try await read(dreamID)

        let originalCount = dream.segments.count
        dream.segments.removeAll { $0.id == segmentID }

        guard dream.segments.count < originalCount else {
            throw DreamStoreError.segmentNotFound(segmentID)       // new case below
        }
        try await write(dream)                                    // atomic replace
    }
    
    public func allDreams() async throws -> [Dream] {
        let files = try FileManager.default.contentsOfDirectory(at: root,
                            includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }

        var dreams: [Dream] = []
        for url in files {
            do { dreams.append(try decoder.decode(Dream.self,
                              from: Data(contentsOf: url))) }
            catch { /* skip corrupt file, or wrap if you prefer */ }
        }
        dreams.sort { $0.created > $1.created }      // newest first
        return dreams
    }
    
    public func updateTitle(dreamID: UUID, title: String) async throws {
        var dream = try await read(dreamID)
        dream.title = title
        try await write(dream)
    }
    
    public func getTranscript(dreamID: UUID) async throws -> String? {
        let dream = try await read(dreamID)
        let transcript = dream.transcript ?? ""
        return transcript
    }
    
    internal func replaceSegments(
            _ id: UUID,
            with newSegments: [AudioSegment]
        ) async throws {
            var dream = try await read(id)
            dream.segments = newSegments
            try await write(dream)
        }

        /// Insert-or-update: if we already have a JSON file with this ID
        /// it is overwritten, otherwise a fresh file is created.
        /// Lets the sync layer converge on the server’s canonical dream list.
        internal func upsert(_ dream: Dream) async throws {
            try await write(dream)
        }

        /// Generic mutate-in-place helper.  The closure receives an `inout Dream`
        /// so callers can tweak any field without re-decoding outside this actor.
        internal func updateDream(
            _ id: UUID,
            mutating body: (inout Dream) -> Void
        ) async throws {
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
        // Atomic write: encode to a tmp file then replace.
        do {
            let tmpURL = fileURL.appendingPathExtension("tmp")
            try data.write(to: tmpURL, options: .atomic)
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tmpURL)
        } catch {
            throw DreamStoreError.io(error)
        }
    }
}
