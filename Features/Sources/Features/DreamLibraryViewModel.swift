import CoreModels
import Infrastructure
import DomainLogic
import Foundation
import SwiftUI
import Observation

@MainActor
final class DreamLibraryViewModel: ObservableObject {
    @Published private(set) var dreams: [Dream] = []
    /// Non-nil when the latest `refresh()` failed. Use this to present an alert in the view layer.
    @Published var refreshError: Error?

    let store: SyncingDreamStore

    init(store: SyncingDreamStore) {
        self.store = store
    }

    /// Fetches all dreams from the store and updates `dreams`.
    /// – Cancels gracefully when the surrounding `Task` is cancelled.
    /// – Publishes `refreshError` when an error is encountered so the UI can react.
    func refresh() async {
        guard !Task.isCancelled else { return }
        do {
            let all = try await store.allDreams()
            guard !Task.isCancelled else { return }
            self.dreams = all
            refreshError = nil
        } catch {
            guard !Task.isCancelled else { return }
            refreshError = error
            NSLog("DreamLibraryViewModel.refresh error: \(error)")
        }
    }
}
