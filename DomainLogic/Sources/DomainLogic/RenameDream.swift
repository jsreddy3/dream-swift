import Foundation
import CoreModels

public struct RenameDream: Sendable {
    private let store: DreamStore
    public init(store: DreamStore) { self.store = store }

    public func callAsFunction(
        dreamID: UUID,
        newTitle: String
    ) async throws {
        try await store.updateTitle(dreamID: dreamID, title: newTitle)
    }
}
