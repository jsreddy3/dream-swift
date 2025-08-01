//
//  DreamEntryViewModel.swift
//

import Foundation               // async/await, Duration
import SwiftUI                  // @MainActor, ObservableObject
import UIKit                    // UIImpactFeedbackGenerator
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
    @Published var shareText: String?           // Generated shareable text
    @Published var isExpandingAnalysis = false  // Loading state for expanded analysis
    @Published var expandedAnalysisMessage: String? // Loading message
    @Published var isGeneratingImage = false     // Loading state for image generation
    @Published var imageGenerationMessage: String? // Loading message for image
    @Published var showingImageFullscreen = false // Fullscreen image viewer
    @Published var hasContentPolicyViolation = false // Dream was flagged for content

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
        // Check if dream already has content policy violation
        if dream.imageStatus == "policy_violation" {
            self.hasContentPolicyViolation = true
        }
        Task { [weak self] in await self?.ensureSummary() }
    }

    // ──────────────────────────────────────────────────────────────
    //  Public helpers (unchanged from the original file)
    // ──────────────────────────────────────────────────────────────
    @MainActor
    func refresh() async {
        do   { 
            let updatedDream = try await self.store.getDream(self.dream.id)
            #if DEBUG
            print("DEBUG: refresh completed - analysis: \(updatedDream.analysis != nil ? "exists" : "nil")")
            print("DEBUG: Current dream analysis before update: \(self.dream.analysis != nil)")
            #endif
            
            // Check if analysis just became available (completion moment)
            let wasAnalysisNil = self.dream.analysis == nil
            let nowHasAnalysis = updatedDream.analysis != nil
            
            self.dream = updatedDream
            #if DEBUG
            print("DEBUG: Current dream analysis after update: \(self.dream.analysis != nil)")
            #endif
            
            // Celebrate completion if analysis just appeared
            if wasAnalysisNil && nowHasAnalysis {
                #if DEBUG
                print("DEBUG: Analysis just completed! Triggering celebration haptics.")
                #endif
                self.celebrateCompletion()
            }
            
            // Explicitly trigger view update
            self.objectWillChange.send()
        }
        catch { 
            NSLog("refresh failed: \(error)")
            #if DEBUG
            print("DEBUG: refresh error: \(error)")
            #endif
        }
    }

    func interpret() async {
        #if DEBUG
        print("DEBUG: interpret() called")
        #endif
        guard self.dream.analysis == nil else { 
            #if DEBUG
            print("DEBUG: analysis already exists")
            #endif
            return 
        }
        // Clear any previous error when retrying
        self.errorMessage = nil
        self.errorAction = nil
        
        // Determine analysis type based on content size
        let analysisType = self.dream.suggestedAnalysisType
        let wordCount = self.dream.contentWordCount
        
        #if DEBUG
        print("DEBUG: Dream content has \(wordCount) words, using \(analysisType.rawValue) analysis")
        #endif
        
        // Set initial status message based on analysis type
        self.statusMessage = analysisType.loadingMessage
        
        await runWithBusyAndErrors {
            #if DEBUG
            print("DEBUG: calling requestAnalysis with type: \(analysisType.rawValue)")
            #endif
            let requestStartTime = Date()
            try await self.store.requestAnalysis(for: self.dream.id, type: analysisType)
            #if DEBUG
            print("DEBUG: requestAnalysis completed at \(Date()), starting polling...")
            #endif
            
            // Poll every 2 seconds for up to 60 seconds
            let maxAttempts = 30
            let pollInterval: Duration = .seconds(2)
            
            // Context-aware interpretation messages based on analysis type
            let interpretationMessages: [String]
            switch analysisType {
            case .micro:
                interpretationMessages = [
                    "Reflecting on key themes...",
                    "Identifying core symbols...",
                    "Capturing essence...",
                    "Distilling meaning..."
                ]
            case .short:
                interpretationMessages = [
                    "Analyzing main themes...",
                    "Examining dream symbols...",
                    "Exploring emotional context...",
                    "Connecting dream elements..."
                ]
            case .medium:
                interpretationMessages = [
                    "Analyzing symbolic patterns...",
                    "Examining archetypal themes...",
                    "Mapping emotional landscapes...",
                    "Decoding metaphorical content...",
                    "Identifying unconscious elements...",
                    "Synthesizing dream narrative..."
                ]
            case .comprehensive:
                interpretationMessages = [
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
            }
            
            // Randomly select messages for rotation (limit based on analysis type)
            let messageCount = min(4, interpretationMessages.count)
            let selectedMessages = Array(interpretationMessages.shuffled().prefix(messageCount))
            
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
                
                #if DEBUG
                print("DEBUG: Poll attempt \(attempt)/\(maxAttempts), elapsed: \(elapsedSeconds)s, status: \(self.statusMessage ?? "nil")")
                #endif
                try await Task.sleep(for: pollInterval)
                await self.refresh()
                
                if self.dream.analysis != nil {
                    #if DEBUG
                    print("DEBUG: Analysis found on attempt \(attempt) after \(elapsedSeconds)s!")
                    #endif
                    self.statusMessage = nil  // Clear status message
                    
                    // Celebrate completion with haptic feedback
                    self.celebrateCompletion()
                    
                    break
                }
            }
            
            let finalElapsed = Date().timeIntervalSince(requestStartTime)
            #if DEBUG
            print("DEBUG: interpret flow completed - analysis: \(self.dream.analysis != nil ? "found" : "not found"), total time: \(finalElapsed)s")
            #endif
            
            // Log timeout if we didn't get analysis
            if self.dream.analysis == nil {
                #if DEBUG
                print("ERROR: Analysis timed out after \(finalElapsed) seconds")
                #endif
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
    //  Sharing functionality
    // ──────────────────────────────────────────────────────────────
    @MainActor
    func generateShareText() {
        let intros = [
            "Hey! I wanted to share this dream I had - it was so vivid:",
            "I had the most incredible dream last night:",
            "You have to hear about this dream I just had:",
            "I had such an interesting dream - thought you'd find it fascinating:",
            "Just woke up from the most amazing dream:",
            "Had this wild dream that I can't stop thinking about:",
            "I had a dream that felt so real - wanted to share it with you:",
            "This dream was too good not to share:",
            "You know how sometimes dreams stay with you? Had one of those:",
            "I rarely remember my dreams, but this one was so vivid:"
        ]
        
        let randomIntro = intros.randomElement() ?? intros[0]
        
        let title = dream.title.isEmpty ? "Untitled Dream" : dream.title
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d, yyyy"
        let formattedDate = dateFormatter.string(from: dream.created_at)
        
        // Get summary or fallback to transcript
        let content = dream.summary ?? dream.transcript ?? "A mysterious dream..."
        
        // Truncate content if too long for sharing
        let maxContentLength = 200
        let truncatedContent = content.count > maxContentLength ? 
            String(content.prefix(maxContentLength)) + "..." : content
        
        // For now, use a placeholder URL - this will need backend implementation
        let shareURL = "https://dreamapp.com/shared/\(dream.id)"
        
        let shareText = """
        \(randomIntro)

        🌙 \(title) (\(formattedDate))

        \(truncatedContent)

        Check out the full dream and interpretation: \(shareURL)
        """
        
        self.shareText = shareText
    }

    // ──────────────────────────────────────────────────────────────
    //  Expanded Analysis functionality
    // ──────────────────────────────────────────────────────────────
    func requestExpandedAnalysis() async {
        guard self.dream.analysis != nil else { 
            #if DEBUG
            print("DEBUG: No initial analysis available for expanded analysis")
            #endif
            return 
        }
        
        // Check if expanded analysis already exists
        if self.dream.expandedAnalysis != nil {
            #if DEBUG
            print("DEBUG: Expanded analysis already exists")
            #endif
            return
        }
        
        let expandingMessages = [
            "Expanding analysis...",
            "Exploring deeper meanings...",
            "Uncovering hidden symbols...",
            "Diving into psychological themes...",
            "Examining emotional connections...",
            "Analyzing symbolic patterns...",
            "Connecting dream elements...",
            "Revealing deeper insights...",
            "Exploring personal significance...",
            "Unraveling dream layers..."
        ]
        
        self.isExpandingAnalysis = true
        self.expandedAnalysisMessage = expandingMessages.randomElement()
        
        // Rotate loading messages every 3 seconds
        let messageTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            DispatchQueue.main.async {
                if self.isExpandingAnalysis {
                    self.expandedAnalysisMessage = expandingMessages.randomElement()
                }
            }
        }

        do {
            #if DEBUG
            print("DEBUG: calling requestExpandedAnalysis")
            #endif
            try await self.store.requestExpandedAnalysis(for: self.dream.id)
            #if DEBUG
            print("DEBUG: requestExpandedAnalysis completed, refreshing...")
            #endif
            
            // Poll for the expanded analysis (similar to interpret method)
            let maxAttempts = 15  // 30 seconds total with 2 second intervals
            let pollInterval: Duration = .seconds(2)
            
            for attempt in 1...maxAttempts {
                #if DEBUG
                print("DEBUG: Poll attempt \(attempt)/\(maxAttempts) for expanded analysis")
                #endif
                try await Task.sleep(for: pollInterval)
                await self.refresh()
                
                if self.dream.expandedAnalysis != nil {
                    #if DEBUG
                    print("DEBUG: Expanded analysis found on attempt \(attempt)!")
                    #endif
                    break
                }
            }
            
            if self.dream.expandedAnalysis == nil {
                #if DEBUG
                print("ERROR: Expanded analysis timed out after polling")
                #endif
            }
        } catch {
            #if DEBUG
            print("DEBUG: requestExpandedAnalysis error: \(error)")
            #endif
            
            // Check if it's a timeout error
            if error is CancellationError || 
               (error as? SyncingDreamStoreError) == .timeout ||
               (error as? URLError)?.code == .timedOut {
                // Continue polling in background even after timeout
                Task.detached { [weak self] in
                    guard let self else { return }
                    
                    // Poll for another 30 seconds in background
                    for attempt in 1...15 {
                        try? await Task.sleep(for: .seconds(2))
                        await self.refresh()
                        
                        if await self.dream.expandedAnalysis != nil {
                            #if DEBUG
                            print("DEBUG: Expanded analysis found in background on attempt \(attempt)!")
                            #endif
                            break
                        }
                    }
                }
            }
        }
        
        // Clean up after async operation completes
        self.isExpandingAnalysis = false
        self.expandedAnalysisMessage = nil
        messageTimer.invalidate()
    }
    
    // ──────────────────────────────────────────────────────────────
    //  Image Generation functionality
    // ──────────────────────────────────────────────────────────────
    func generateImage() async {
        guard dream.imageUrl == nil else {
            #if DEBUG
            print("DEBUG: Image already exists for dream")
            #endif
            return
        }
        
        // Check if we have content to generate from
        guard dream.transcript != nil || dream.summary != nil else {
            #if DEBUG
            print("DEBUG: No transcript or summary available for image generation")
            #endif
            return
        }
        
        let generatingMessages = [
            "Creating dreamscape...",
            "Painting your dreams...",
            "Visualizing ethereal visions...",
            "Weaving dream threads...",
            "Crystallizing dream imagery...",
            "Manifesting visual magic...",
            "Rendering subconscious art...",
            "Composing dream palette...",
            "Bringing dreams to life...",
            "Crafting mystical imagery..."
        ]
        
        self.isGeneratingImage = true
        self.imageGenerationMessage = generatingMessages.randomElement()
        
        // Create a timer to cycle through messages
        let messageTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            Task { @MainActor in
                self.imageGenerationMessage = generatingMessages.randomElement()
            }
        }
        
        #if DEBUG
        print("DEBUG: Requesting image generation for dream \(dream.id)")
        #endif
        
        do {
            // Call the API to generate image
            let updatedDream = try await store.generateImage(for: dream.id)
            
            // Update our local dream with the image info
            self.dream = updatedDream
            
            #if DEBUG
            print("DEBUG: Image generated successfully: \(updatedDream.imageUrl ?? "nil")")
            #endif
        } catch {
            #if DEBUG
            print("DEBUG: Image generation failed: \(error)")
            #endif
            
            // Check if it's a content policy violation
            if let remoteError = error as? RemoteError,
               case .contentPolicyViolation = remoteError {
                self.hasContentPolicyViolation = true
                // Update the local dream object to persist the status
                self.dream.imageStatus = "policy_violation"
            }
        }
        
        // Clean up
        self.isGeneratingImage = false
        self.imageGenerationMessage = nil
        messageTimer.invalidate()
    }

    // ──────────────────────────────────────────────────────────────
    //  Haptic Feedback for Dream Completion
    // ──────────────────────────────────────────────────────────────
    @MainActor
    private func celebrateCompletion() {
        // Only provide haptic feedback if device supports it and user hasn't disabled it
        guard UIDevice.current.systemName == "iOS" else { return }
        
        // Heavy impact for accomplishment feeling
        let heavyFeedback = UIImpactFeedbackGenerator(style: .heavy)
        heavyFeedback.prepare() // Prepare for immediate response
        heavyFeedback.impactOccurred()
        
        // Follow-up celebration pattern: two light taps
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let lightFeedback = UIImpactFeedbackGenerator(style: .light)
            lightFeedback.prepare()
            lightFeedback.impactOccurred()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                lightFeedback.impactOccurred()
            }
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
            #if DEBUG
            print("ERROR: \(errorDetails)")
            #endif
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
            
            #if DEBUG
            print("DEBUG: Error message shown to user: \(self.errorMessage ?? "nil"), action: \(self.errorAction ?? .close)")
            #endif
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
