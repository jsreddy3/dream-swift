import SwiftUI
import DomainLogic          // StartCaptureDream, StopCaptureDream, CompleteDream, RenameDream
import Infrastructure       // AudioRecorderActor, RemoteDreamStore
import CoreModels
import Observation

/// Captures every externally-visible phase of the capture workflow.
enum CaptureState: Equatable {
    case idle                              // nothing started yet
    case recording                         // mic rolling
    case clipped                            // at least one segment recorded, mic stopped
    case saving                            // user tapped Done and we are persisting
    case saved                             // dream completed successfully
    case failed(String)                    // bubble up a user-readable error
}

@MainActor
@Observable                    // new macro in Swift 5.10 replaces @Published boilerplate
public final class CaptureViewModel {
    let store: SyncingDreamStore            // ← expose for Library use

    private let start: StartCaptureDream
    private let stop: StopCaptureDream
    private let done: CompleteDream
    private let saveText: SaveTextSegment
    private let cont: StartAdditionalSegment
    private let querySegments: (UUID) async throws -> [Segment]
    private let deleteSegment: (UUID, UUID) async throws -> Void
    

    var state: CaptureState = .idle          // drives the entire UI
    var segments: [Segment] = []              // drives the on-screen list
    var isExtending = false                   // tracks if user clicked "Extend Dream"

    private var dreamID: UUID?
    private var handle: RecordingHandle?
    private var order = 0
    private var uploadsTask: Task<Void, Never>?   // stored property
    
    @ObservationIgnored
    var isTyping = false
    
    @ObservationIgnored
    private(set) var lastSavedID: UUID?
    
    public init(recorder: AudioRecorderActor, store: SyncingDreamStore) {
        self.store = store
        start = StartCaptureDream(recorder: recorder, store: store)
        stop  = StopCaptureDream(recorder: recorder, store: store)
        done  = CompleteDream(store: store)
        cont  = StartAdditionalSegment(recorder: recorder, store: store)
        saveText = SaveTextSegment(store: store)
        
        querySegments = { try await store.segments(dreamID: $0) }
        deleteSegment = { try await store.removeSegment(dreamID: $0, segmentID: $1) }
        
        listen(to: store)
    }

    public func startOrStop() {
        switch state {
        case .idle, .clipped, .saved:
            Task { await beginRecording() }
        case .recording:
            Task { await endRecording() }
        default:
            break
        }
    }
    
    public func startOrStopText(_ text: String) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }

        switch state {
        case .idle, .clipped where !isTyping:
            isTyping = true
            state = .recording                       // greys out picker instantly
        case .recording:
            Task { await finishText(cleaned) }       // ✓ tapped
        default:
            break
        }
    }

    private func finishText(_ text: String) async {
        let saver = saveText                      // ← ① local copy on MainActor

        do {
            if dreamID == nil {                   // may suspend
                let result = try await start()
                dreamID = result.dreamID
            }

            let newSeg = try await saver(         // ← ② use the copy, not self.saveText
                dreamID: dreamID!,
                text: text,
                order: order
            )

            order += 1
            segments.append(newSeg)
            try await refreshSegments()

            isTyping = false
            isExtending = false  // reset when we go back to clipped
            state = .clipped
        } catch {
            state = .failed("Text save error: \(error.localizedDescription)")
        }
    }


    func finish() {
        guard case .clipped = state else { return }
        Task { await completeDream() }
    }
    
    func extend() {
        guard case .clipped = state else { return }
        isExtending = true
    }
    
    func remove(_ segment: Segment) {
        guard let id = dreamID else { return }
        Task {
            do {
                try await deleteSegment(id, segment.id)
                try await refreshSegments()
                order = segments.count                       // keep order monotonic
            } catch {
                state = .failed("Delete error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: private helpers
    
    private func listen(to store: SyncingDreamStore) {
        uploadsTask = Task {                      // this inherits MainActor context
            for await result in await store.uploads {   // suspends until something is yielded
                guard result.dreamID == dreamID else { continue }

                // If the server kindly gave us speech-to-text, integrate it.
                if !result.transcript.isEmpty {
                    let cleaned = result.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                }

                // After any upload completes we fetch the authoritative segment list.
                // This reconciles server-side reordering or duration adjustments.
                try? await refreshSegments()
            }
        }
    }

    private func beginRecording() async {
        do {
            if dreamID == nil {
                let result = try await start()
                dreamID = result.dreamID
                handle  = result.handle
            } else {
                handle = try await cont(dreamID: dreamID!)
            }
            state = .recording
        } catch {
            state = .failed("Mic error: \(error.localizedDescription)")
        }
    }
        
    private func endRecording() async {
        guard let id = dreamID, let h = handle else { return }
        do {
            let newSeg = try await stop(dreamID: id, handle: h, order: order)
            order += 1
            segments.append(newSeg)              // ← row appears immediately
            try await refreshSegments()           // still reconciles if online
            isExtending = false                  // reset when we go back to clipped
            state = .clipped
        } catch {
            state = .failed("Stop error: \(error.localizedDescription)")
        }
    }

    private func completeDream() async {
        guard let id = dreamID else { return }
        state = .saving
        do {
            try await done(dreamID: id)
            lastSavedID = id
            reset()
            // Don't reset to idle - we're navigating away
        } catch {
            state = .failed("Save error: \(error.localizedDescription)")
        }
    }
    
    private func refreshSegments() async throws {
        guard let id = dreamID else { return }
        let latest = try await querySegments(id)

        #if DEBUG
        let all = latest.map(\.id)
        let unique = Set(all)
        assert(all.count == unique.count, "Duplicate IDs in segments: \(all)")
        #endif

        segments = latest
    }

    private func reset() {
        dreamID = nil
        handle  = nil
        order   = 0
        segments.removeAll()
        isExtending = false
    }
    
    deinit {
        // Take a local snapshot of the handle.  This single line does
        // touch a main-actor-isolated property, so we wrap the access in
        // a one-off hop onto the main actor.  The hop finishes synchronously
        // before we leave deinit, therefore the handle is valid and 'self'
        // is no longer captured by the closure that follows.
        let handle: Task<Void, Never>? = MainActor.assumeIsolated { uploadsTask }

        // Now cancel from whichever thread happens to be running deinit.
        // 'cancel()' is inherently thread-safe.
        handle?.cancel()
    }
}
