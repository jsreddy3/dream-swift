// DomainLogicTests/CompleteDreamTests.swift
import XCTest
import DomainLogic
import CoreModels

private actor InMemoryDreamStore: DreamStore {
    private(set) var completedID: UUID?
    func insertNew(_ dream: Dream) async throws {}
    func appendSegment(dreamID: UUID, segment: AudioSegment) async throws {}
    func markCompleted(_ dreamID: UUID) async throws { completedID = dreamID }
}

final class CompleteDreamTests: XCTestCase {
    func testCompleteDreamMarksDream() async throws {
        let store = InMemoryDreamStore()
        let useCase = CompleteDream(store: store)

        let id = UUID()
        try await useCase(dreamID: id)

        let flagged = await store.completedID
        XCTAssertEqual(flagged, id)
    }
}
