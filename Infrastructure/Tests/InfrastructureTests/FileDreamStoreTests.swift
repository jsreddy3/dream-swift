import XCTest
@testable import Infrastructure          // exposes internal symbols
import CoreModels

final class FileDreamStoreTests: XCTestCase {

    private var tmpDir: URL!
    private var store: FileDreamStore!

    override func setUpWithError() throws {
        let base = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        tmpDir = base.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        store = FileDreamStore(customRootURL: tmpDir)      // ← new init
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmpDir)
    }

    func testInsertAppendCompleteRoundTrip() async throws {
        let dream = Dream(title: "Test")
        try await store.insertNew(dream)

        let seg = AudioSegment(filename: "a.m4a", duration: 3, order: 0)
        try await store.appendSegment(dreamID: dream.id, segment: seg)
        try await store.markCompleted(dream.id)

        let reloaded = try await store.debug_read(dream.id)
        XCTAssertEqual(reloaded.state, DreamState.completed)      // explicit enum type
        XCTAssertEqual(reloaded.segments.count, 1)
        XCTAssertEqual(reloaded.segments[0].filename, "a.m4a")
    }
}
