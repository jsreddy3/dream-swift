//  SaveTextSegment.swift  (DomainLogic)
import CoreModels
import Foundation

public struct SaveTextSegment: Sendable {          // ← add Sendable
    public let store: DreamStore                   // DreamStore is already Sendable

    public init(store: DreamStore) { self.store = store }

    @discardableResult
    public func callAsFunction(
        dreamID: UUID,
        text: String,
        order: Int
    ) async throws -> Segment {

        let seg = Segment.text(order: order, text: text)
        try await store.appendSegment(dreamID: dreamID, segment: seg)
        return seg
    }
}
