import Foundation
import CoreModels

/// Deletes a dream and all associated data.
public struct DeleteDream: Sendable {
    private let store: DreamStore
    public init(store: DreamStore) { self.store = store }

    public func callAsFunction(dreamID: UUID) async throws {
        try await store.deleteDream(dreamID)
    }
}