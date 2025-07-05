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
        print("📱 DreamLibraryViewModel.refresh: Starting refresh")
        do {
            let all = try await store.allDreams()
            print("📱 DreamLibraryViewModel.refresh: Received \(all.count) dreams from store")
            for dream in all {
                print("  - Dream \(dream.id): title='\(dream.title)', created=\(dream.created)")
            }
            await MainActor.run { 
                self.dreams = all 
                print("📱 DreamLibraryViewModel.refresh: Updated @Published dreams array")
            }
        } catch {
            NSLog("DreamLibraryViewModel.refresh error: \(error)")
        }
    }
}
