import CoreModels
import Infrastructure
import DomainLogic
import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
final class DreamLibraryViewModel {
    private let fetch: GetDreamLibrary
    private let segmentsOf: (UUID) async throws -> [AudioSegment]
    private let renamer: RenameDream                                // ← new

    var dreams: [Dream] = []

    init(store: RemoteDreamStore) {
        fetch = GetDreamLibrary(store: store)
        segmentsOf = { try await store.segments(dreamID: $0) }
        renamer     = RenameDream(store: store)
    }

    func refresh() { Task { try? await dreams = fetch() } }

    func segments(for dream: Dream) async throws -> [AudioSegment] {
        try await segmentsOf(dream.id)
    }

    func rename(_ dream: Dream, to newTitle: String) async {
        guard !newTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        do  { try await renamer(dreamID: dream.id, newTitle: newTitle)
              refresh() }                                          // pull updated list
        catch { /* surface error if you like */ }
    }
}
