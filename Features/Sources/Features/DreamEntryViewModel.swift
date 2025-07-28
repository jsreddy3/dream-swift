//
//  DreamEntryViewModel.swift
//

import Foundation               // async/await, Duration
import SwiftUI                  // @MainActor, ObservableObject
import Infrastructure
import DomainLogic
import CoreModels

enum ErrorAction {
    case retry          // Show "Try Again" button
    case close          // Show "Close" button only
    case wait           // Show "OK" button (for timeout)
}

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
    @Published var statusMessage: String?       // For progress updates
    @Published var errorAction: ErrorAction?    // What action user can take

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
            print("DEBUG: Current dream analysis after update: \(self.dream.analysis != nil)")
            
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
        // Clear any previous error when retrying
        self.errorMessage = nil
        self.errorAction = nil
        
        // Set initial status message BEFORE entering busy state
        self.statusMessage = "Initiating dream analysis..."
        
        await runWithBusyAndErrors {
            print("DEBUG: calling requestAnalysis")
            let requestStartTime = Date()
            try await self.store.requestAnalysis(for: self.dream.id)
            print("DEBUG: requestAnalysis completed at \(Date()), starting polling...")
            
            // Poll every 2 seconds for up to 60 seconds
            let maxAttempts = 30
            let pollInterval: Duration = .seconds(2)
            
            // Bank of sophisticated interpretation messages
            let interpretationMessages = [
                "Analyzing symbolic patterns...",
                "Examining archetypal themes...",
                "Applying Jungian methodology...",
                "Cross-referencing dream motifs...",
                "Identifying unconscious elements...",
                "Mapping emotional landscapes...",
                "Decoding metaphorical content...",
                "Evaluating shadow aspects...",
                "Processing collective unconscious themes...",
                "Synthesizing dream narrative..."
            ]
            
            // Randomly select 4 messages for the first 20 seconds
            let selectedMessages = Array(interpretationMessages.shuffled().prefix(4))
            
            // Set initial status message immediately
            self.statusMessage = selectedMessages[0]
            
            for attempt in 1...maxAttempts {
                let elapsedSeconds = Int(Date().timeIntervalSince(requestStartTime))
                
                // Update status message based on elapsed time ranges
                let messageIndex = elapsedSeconds / 5  // Every 5 seconds
                if messageIndex <= 3 {
                    // First 20 seconds - use selected interpretation messages
                    self.statusMessage = selectedMessages[min(messageIndex, 3)]
                } else {
                    // After 20 seconds - use apologetic messages
                    let apologeticMessages = [
                        "This is taking longer than usual...",
                        "Still processing your complex dream...",
                        "Sorry for the wait...",
                        "Almost done, we promise...",
                        "Just a few more moments...",
                        "Nearly finished...",
                        "Wrapping up the interpretation..."
                    ]
                    let apologeticIndex = min(messageIndex - 4, apologeticMessages.count - 1)
                    self.statusMessage = apologeticMessages[apologeticIndex]
                }
                
                print("DEBUG: Poll attempt \(attempt)/\(maxAttempts), elapsed: \(elapsedSeconds)s, status: \(self.statusMessage ?? "nil")")
                try await Task.sleep(for: pollInterval)
                await self.refresh()
                
                if self.dream.analysis != nil {
                    print("DEBUG: Analysis found on attempt \(attempt) after \(elapsedSeconds)s!")
                    self.statusMessage = nil  // Clear status message
                    break
                }
            }
            
            let finalElapsed = Date().timeIntervalSince(requestStartTime)
            print("DEBUG: interpret flow completed - analysis: \(self.dream.analysis != nil ? "found" : "not found"), total time: \(finalElapsed)s")
            
            // Log timeout if we didn't get analysis
            if self.dream.analysis == nil {
                print("ERROR: Analysis timed out after \(finalElapsed) seconds")
                // TODO: Send this log to server
            }
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
        // Don't clear statusMessage here - let the work function manage it
        defer { 
            self.isBusy = false 
            self.statusMessage = nil  // Clear status message when done
        }

        do {
            try await work()
            self.errorMessage = nil                 // clear any prior error
        } catch {
            // Log the error for debugging
            let errorDetails = """
            Error in dream interpretation:
            - Dream ID: \(self.dream.id)
            - Error Type: \(type(of: error))
            - Error Description: \(error.localizedDescription)
            - Full Error: \(error)
            - Timestamp: \(Date())
            """
            print("ERROR: \(errorDetails)")
            // TODO: Send errorDetails to server logging
            
            // Differentiate between error types
            if error is CancellationError {
                self.errorMessage = "Analysis timed out. The interpretation will appear in your library when ready."
                self.errorAction = .wait
            } else if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet, .networkConnectionLost:
                    self.errorMessage = "No internet connection. Please check your connection and try again."
                    self.errorAction = .retry
                case .timedOut:
                    self.errorMessage = "Request timed out. Please try again."
                    self.errorAction = .retry
                case .cannotFindHost, .cannotConnectToHost:
                    self.errorMessage = "Cannot reach the server. Please try again later."
                    self.errorAction = .retry
                default:
                    self.errorMessage = "Network error. Please try again."
                    self.errorAction = .retry
                }
            } else {
                self.errorMessage = "Something went wrong. Please try again."
                self.errorAction = .retry
            }
            
            print("DEBUG: Error message shown to user: \(self.errorMessage ?? "nil"), action: \(self.errorAction ?? .close)")
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
