import CoreModels
import Infrastructure
import DomainLogic
import Foundation
import SwiftUI
import Observation

@MainActor
final class DreamLibraryViewModel: ObservableObject {
    @Published private(set) var dreams: [Dream] = []

    let store: SyncingDreamStore

    init(store: SyncingDreamStore) {
        self.store = store
        Task { await refresh() }
    }

    func refresh() async {
        do {
            let all = try await store.allDreams()
            await MainActor.run { self.dreams = all }
        } catch {
            NSLog("DreamLibraryViewModel.refresh error: \(error)")
        }
    }
}
