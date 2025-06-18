// DomainLogic/Sources/DomainLogic/CompleteDream.swift
import Foundation
import CoreModels

public struct CompleteDream: Sendable {
    private let store: DreamStore
    public init(store: DreamStore) { self.store = store }

    public func callAsFunction(dreamID: UUID) async throws {
        try await store.markCompleted(dreamID)
    }
}
