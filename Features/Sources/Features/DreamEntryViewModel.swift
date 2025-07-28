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
    @Published var isEditMode    = false
    @Published var editedTitle: String = ""
    @Published var editedSummary: String = ""
    @Published var hasAnalysis: Bool = false

    // ──────────────────────────────────────────────────────────────
    //  Private bits
    // ──────────────────────────────────────────────────────────────
    private let store: DreamStore
    private let timeout: Duration = .seconds(10)

    // ──────────────────────────────────────────────────────────────
    //  Init
    // ──────────────────────────────────────────────────────────────
    init(dream: Dream, store: DreamStore) {
        self.dream = dream
        self.store = store
        self.hasAnalysis = dream.analysis != nil
        Task { [weak self] in await self?.ensureSummary() }
    }

    // ──────────────────────────────────────────────────────────────
    //  Public helpers (unchanged from the original file)
    // ──────────────────────────────────────────────────────────────
    @MainActor
    func refresh() async {
        do   { 
            let updatedDream = try await self.store.getDream(self.dream.id)
            print("DEBUG: refresh completed - analysis: \(updatedDream.analysis != nil ? "exists" : "nil")")
            print("DEBUG: Current dream analysis before update: \(self.dream.analysis != nil)")
            self.dream = updatedDream
            self.hasAnalysis = updatedDream.analysis != nil
            print("DEBUG: Current dream analysis after update: \(self.dream.analysis != nil)")
            print("DEBUG: hasAnalysis updated to: \(self.hasAnalysis)")
            
            // Explicitly trigger view update
            self.objectWillChange.send()
        }
        catch { 
            NSLog("refresh failed: \(error)")
            print("DEBUG: refresh error: \(error)")
        }
    }

    func interpret() async {
        print("DEBUG: interpret() called")
        guard self.dream.analysis == nil else { 
            print("DEBUG: analysis already exists")
            return 
        }
        await runWithBusyAndErrors {
            print("DEBUG: calling requestAnalysis")
            try await self.store.requestAnalysis(for: self.dream.id)
            print("DEBUG: requestAnalysis completed, starting polling...")
            
            // Poll every 2 seconds for up to 60 seconds
            let maxAttempts = 30
            let pollInterval: Duration = .seconds(2)
            
            for attempt in 1...maxAttempts {
                print("DEBUG: Poll attempt \(attempt)/\(maxAttempts)")
                try await Task.sleep(for: pollInterval)
                await self.refresh()
                
                if self.dream.analysis != nil {
                    print("DEBUG: Analysis found on attempt \(attempt)!")
                    break
                }
            }
            
            print("DEBUG: interpret flow completed - analysis: \(self.dream.analysis != nil ? "found" : "not found")")
        }
    }

    func enterEditMode() {
        isEditMode = true
        editedTitle = dream.title
        editedSummary = dream.summary ?? ""
    }

    func cancelEdit() {
        isEditMode = false
        editedTitle = ""
        editedSummary = ""
    }

    func saveEdits() async {
        await runWithBusyAndErrors {
            let titleChanged = self.editedTitle != self.dream.title
            let summaryChanged = self.editedSummary != (self.dream.summary ?? "")
            
            // Use combined update if both changed, otherwise update individually
            if titleChanged && summaryChanged {
                try await self.store.updateTitleAndSummary(
                    dreamID: self.dream.id, 
                    title: self.editedTitle, 
                    summary: self.editedSummary
                )
            } else if titleChanged {
                try await self.store.updateTitle(dreamID: self.dream.id, title: self.editedTitle)
            } else if summaryChanged {
                try await self.store.updateSummary(dreamID: self.dream.id, summary: self.editedSummary)
            }
            
            // Refresh to get updated dream
            await self.refresh()
            
            // Exit edit mode
            self.isEditMode = false
            self.editedTitle = ""
            self.editedSummary = ""
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
