import CoreModels
import Infrastructure
import DomainLogic
import Foundation
import SwiftUI

@MainActor
@Observable
final class DreamLibraryViewModel {
    private let fetch: GetDreamLibrary
    private let segmentsOf: (UUID) async throws -> [AudioSegment]

    var dreams: [Dream] = []

    init(store: FileDreamStore) {
        fetch = GetDreamLibrary(store: store)
        segmentsOf = { try await store.segments(dreamID: $0) }
    }

    func refresh() {                                  // ← removed @Sendable
        Task {
            do { dreams = try await fetch() }
            catch { /* publish or ignore */ }
        }
    }


    @Sendable func segments(for dream: Dream) async throws -> [AudioSegment] {
        try await segmentsOf(dream.id)
    }
}
