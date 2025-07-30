import CoreModels
import Infrastructure
import DomainLogic
import Foundation
import SwiftUI
import Observation

@MainActor
public final class DreamLibraryViewModel: ObservableObject {
    @Published private(set) var dreams: [Dream] = []
    /// Non-nil when the latest `refresh()` failed. Use this to present an alert in the view layer.
    @Published var refreshError: Error?

    let store: SyncingDreamStore
    private let deleteDream: DeleteDream

    public init(store: SyncingDreamStore) {
        self.store = store
        self.deleteDream = DeleteDream(store: store)
    }

    /// Fetches all dreams from the store and updates `dreams`.
    /// – Cancels gracefully when the surrounding `Task` is cancelled.
    /// – Publishes `refreshError` when an error is encountered so the UI can react.
    public func refresh() async {
        guard !Task.isCancelled else { return }
        do {
            let all = try await store.allDreams()
            guard !Task.isCancelled else { return }
            
            // Sort dreams by created_at date, newest first
            self.dreams = all.sorted { (dream1: Dream, dream2: Dream) in
                dream1.created_at > dream2.created_at
            }
            refreshError = nil
        } catch {
            guard !Task.isCancelled else { return }
            refreshError = error
            NSLog("DreamLibraryViewModel.refresh error: \(error)")
        }
    }
    
    /// Deletes a dream and refreshes the list
    func deleteDream(_ id: UUID) async {
        do {
            try await deleteDream(dreamID: id)
            // Remove from local array immediately for better UX
            dreams.removeAll { $0.id == id }
            // Refresh from store to ensure consistency
            await refresh()
        } catch {
            refreshError = error
            NSLog("DreamLibraryViewModel.deleteDream error: \(error)")
        }
    }
}
