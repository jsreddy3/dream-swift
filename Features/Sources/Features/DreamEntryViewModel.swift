//
//  DreamEntryViewModel.swift
//

import Foundation               // async/await, Duration
import SwiftUI                  // @MainActor, ObservableObject
import Infrastructure
import DomainLogic
import CoreModels

@MainActor
public final class DreamEntryViewModel: ObservableObject {

    // ──────────────────────────────────────────────────────────────
    //  Published state
    // ──────────────────────────────────────────────────────────────
    @Published private(set) var dream: Dream
    @Published var isBusy        = false
    @Published var errorMessage: String?        // ← new

    // ──────────────────────────────────────────────────────────────
    //  Private bits
    // ──────────────────────────────────────────────────────────────
    private let store: DreamStore
    private let timeout: Duration = .seconds(5)

    // ──────────────────────────────────────────────────────────────
    //  Init
    // ──────────────────────────────────────────────────────────────
    init(dream: Dream, store: DreamStore) {
        self.dream = dream
        self.store = store
        Task { [weak self] in await self?.ensureSummary() }
    }

    // ──────────────────────────────────────────────────────────────
    //  Public helpers (unchanged from the original file)
    // ──────────────────────────────────────────────────────────────
    func refresh() async {
        do   { self.dream = try await self.store.getDream(self.dream.id) }
        catch { NSLog("refresh failed: \(error)") }
    }

    func interpret() async {
        guard self.dream.analysis == nil else { return }
        await runWithBusyAndErrors {
            try await self.store.requestAnalysis(for: self.dream.id)
            try await Task.sleep(for: .seconds(15))      // crude poll
            await self.refresh()
        }
    }

    // ──────────────────────────────────────────────────────────────
    //  Summary generation with timeout + fallback
    // ──────────────────────────────────────────────────────────────
    func ensureSummary() async {
        guard self.dream.summary == nil else { return }
        await runWithBusyAndErrors {
            try await self.generateSummaryWithTimeout()
            await self.refresh()

            if self.dream.summary?.isEmpty ?? true {
                let fallback = self.dream.transcript ?? ""
                if !fallback.isEmpty {
                    try await self.store.generateSummaryFallback(id: self.dream.id,
                                                                text: fallback)
                    await self.refresh()
                }
            }
        }
    }

    // ──────────────────────────────────────────────────────────────
    //  Internal utilities
    // ──────────────────────────────────────────────────────────────
    private func runWithBusyAndErrors(
        _ work: @escaping () async throws -> Void
    ) async {
        self.isBusy = true
        defer { self.isBusy = false }

        do {
            try await work()
            self.errorMessage = nil                 // clear any prior error
        } catch {
            self.errorMessage = "That’s taking a while – it'll be in your library soon :)"
        }
    }

    private func generateSummaryWithTimeout() async throws {
        try await withThrowingTaskGroup(of: Void.self) { [self] group in
            // real network call
            group.addTask {
                _ = try await self.store.generateSummary(for: self.dream.id)
            }
            // watchdog
            group.addTask {
                try await Task.sleep(for: self.timeout)
                throw CancellationError()
            }
            try await group.next()        // whichever finishes first
            group.cancelAll()             // cancel the loser
        }
    }
}
