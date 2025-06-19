import Foundation
import CoreModels

/// Removes one persisted segment from a draft dream.
/// Throws if the dream does not exist or is already completed.
public struct DeleteSegment: Sendable {
    private let store: DreamStore
    public init(store: DreamStore) { self.store = store }

    public func callAsFunction(
        dreamID: UUID,
        segmentID: UUID
    ) async throws {
        try await store.removeSegment(dreamID: dreamID, segmentID: segmentID)
    }
}
