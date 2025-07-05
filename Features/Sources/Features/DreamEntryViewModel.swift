import SwiftUI
import Infrastructure
import DomainLogic
import CoreModels

// MARK: ‑ View‑Model ------------------------------------------------------

@MainActor
final class DreamEntryViewModel: ObservableObject {
    @Published private(set) var dream: Dream
    @Published var isBusy = false

    private let store: DreamStore

    init(dream: Dream, store: DreamStore) {
        self.dream = dream
        self.store = store
        Task { await ensureSummary() }      // kick off immediately
    }

    /// Ensures we have a summary. If the server can’t produce one,
    /// fall back to transcript or “”.
    private func ensureSummary() async {
        guard dream.summary == nil else { return }

        isBusy = true
        defer { isBusy = false }

        // try remote first; returns "" if store is offline-only
        let remoteSummary = try? await store.generateSummary(for: dream.id)

        // refresh local copy (may now hold remote result)
        await refresh()

        // backend returned nil/empty? patch in a local fallback
        if dream.summary?.isEmpty ?? true {
            let fallback = dream.transcript ?? ""
            if !fallback.isEmpty {
                // update on-disk copy so we don’t regenerate every visit
                try? await store.generateSummaryFallback(id: dream.id, text: fallback)
                await refresh()
            }
        }
    }

    /// Simple cache/remote refresh used by callers.
    func refresh() async {
        do   { dream = try await store.getDream(dream.id) }
        catch { NSLog("refresh failed: \(error)") }
    }

    /// Fires interpretation if it hasn’t been run yet.
    func interpret() async {
        guard dream.analysis == nil else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await store.requestAnalysis(for: dream.id)
            try await Task.sleep(for: .seconds(2))
            await refresh()
        } catch { NSLog("interpret failed: \(error)") }
    }
}
