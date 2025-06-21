//
//  FileDreamStoreTests.swift
//  DreamTests
//

import XCTest
@testable import Infrastructure
@testable import DomainLogic
import CoreModels      // brings in Dream, AudioSegment, DreamState

final class FileDreamStoreTests: XCTestCase {

    // MARK: helpers ----------------------------------------------------------

    /// Returns a brand-new temp folder for every test.
    private func freshTempDir() -> URL {
        let path = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: path,
                                                 withIntermediateDirectories: true)
        return path
    }

    /// Convenience factory for a single-segment draft dream.
    private func makeDream() -> Dream {
        let seg = AudioSegment(id: UUID(),
                               filename: "clip.m4a",
                               duration: 5,
                               order: 0,
                               transcript: "")
        // Use a constant second-granularity date to avoid sub-second drift
        let t = Date(timeIntervalSince1970: 1_719_241_281)   // 2025-06-21 07:14:41Z
        return Dream(id: UUID(),
                     created: t,
                     title: "Prototype",
                     transcript: "dog",
                     segments: [seg],
                     state: .draft)
    }

    // MARK: cases ------------------------------------------------------------

    func testInsertReadRoundTrip() async throws {
        let store = FileDreamStore(customRootURL: freshTempDir())
        let dream = makeDream()

        try await store.insertNew(dream)
        let loaded = try await store.debug_read(dream.id)

        XCTAssertEqual(loaded, dream)
    }

    func testAppendAndRemoveSegment() async throws {
        let store = FileDreamStore(customRootURL: freshTempDir())
        let dream = makeDream()
        try await store.insertNew(dream)

        // append ------------------------------------------------------------
        let newSeg = AudioSegment(id: UUID(),
                                  filename: "second.m4a",
                                  duration: 3,
                                  order: 1,
                                  transcript: "")
        try await store.appendSegment(dreamID: dream.id, segment: newSeg)

        var segments = try await store.segments(dreamID: dream.id)
        XCTAssertEqual(segments.count, 2)
        XCTAssertTrue(segments.contains(newSeg))

        // remove ------------------------------------------------------------
        try await store.removeSegment(dreamID: dream.id, segmentID: newSeg.id)
        segments = try await store.segments(dreamID: dream.id)
        XCTAssertEqual(segments, dream.segments)   // back to original one

        // removing again triggers the custom error --------------------------
        await XCTAssertThrowsErrorAsync(
            try await store.removeSegment(dreamID: dream.id, segmentID: newSeg.id)
        ) { error in
            guard case DreamStoreError.segmentNotFound(let id) = error else {
                return XCTFail("wrong error \(error)")
            }
            XCTAssertEqual(id, newSeg.id)
        }
    }

    func testMarkCompletedIsIdempotent() async throws {
        let store = FileDreamStore(customRootURL: freshTempDir())
        let dream = makeDream()
        try await store.insertNew(dream)

        // first call flips state
        try await store.markCompleted(dream.id)
        var reloaded = try await store.debug_read(dream.id)
        XCTAssertEqual(reloaded.state, .completed)

        // second call must be a no-op, not a failure
        try await store.markCompleted(dream.id)
        reloaded = try await store.debug_read(dream.id)
        XCTAssertEqual(reloaded.state, .completed)
    }

    // MARK: async-error helper ----------------------------------------------

    /// Wraps an async throw-ing closure so we can use XCTAssertThrowsError-style checks.
    private func XCTAssertThrowsErrorAsync(
        _ expression: @autoclosure () async throws -> Void,
        _ assert: (Error) -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do { try await expression()
            XCTFail("Expected throw", file: file, line: line)
        } catch { assert(error) }
    }
}
