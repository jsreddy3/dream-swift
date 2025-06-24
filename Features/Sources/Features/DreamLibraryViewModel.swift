import CoreModels
import Infrastructure
import DomainLogic
import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
public final class DreamLibraryViewModel {
    let store: SyncingDreamStore
    
    private let fetch: GetDreamLibrary
    private let segmentsOf: (UUID) async throws -> [AudioSegment]
    private let renamer: RenameDream                                // ← new

    var dreams: [Dream] = []

    init(store: SyncingDreamStore) {
        fetch = GetDreamLibrary(store: store)
        segmentsOf = { try await store.segments(dreamID: $0) }
        renamer     = RenameDream(store: store)
        
        self.store = store
    }

    @MainActor                        // ← guarantees UI-safe writes
    func refresh() async {
        do   { dreams = try await store.allDreams() }   // /list-dreams/
            catch { /* surface an error if you like */ }
    }

    func segments(for dream: Dream) async throws -> [AudioSegment] {
        try await segmentsOf(dream.id)
    }

    func rename(_ dream: Dream, to newTitle: String) async {
        guard !newTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        do  { try await renamer(dreamID: dream.id, newTitle: newTitle)
              await refresh() }                                          // pull updated list
        catch { /* surface error if you like */ }
    }
}
