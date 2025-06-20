import SwiftUI
import DomainLogic          // StartCaptureDream, StopCaptureDream, CompleteDream, RenameDream
import Infrastructure       // AudioRecorderActor, RemoteDreamStore
import CoreModels
import Observation

/// Captures every externally-visible phase of the capture workflow.
enum CaptureState: Equatable {
    case idle                              // nothing started yet
    case recording                         // mic rolling
    case paused                            // at least one segment recorded, mic stopped
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
    private let cont: StartAdditionalSegment
    private let renamer: RenameDream
    private let querySegments: (UUID) async throws -> [AudioSegment]
    private let deleteSegment: (UUID, UUID) async throws -> Void
    

    var state: CaptureState = .idle          // drives the entire UI
    var segments: [AudioSegment] = []              // drives the on-screen list
    var title: String = ""

    private var dreamID: UUID?
    private var handle: RecordingHandle?
    private var order = 0
    private var uploadsTask: Task<Void, Never>?   // stored property

    public init(recorder: AudioRecorderActor, store: SyncingDreamStore) {
        self.store = store
        start = StartCaptureDream(recorder: recorder, store: store)
        stop  = StopCaptureDream(recorder: recorder, store: store)
        done  = CompleteDream(store: store)
        cont  = StartAdditionalSegment(recorder: recorder, store: store)
        renamer = RenameDream(store: store)
        
        querySegments = { try await store.segments(dreamID: $0) }
        deleteSegment = { try await store.removeSegment(dreamID: $0, segmentID: $1) }
        
        listen(to: store)
    }

    func startOrStop() {
        switch state {
        case .idle, .paused, .saved:
            Task { await beginRecording() }
        case .recording:
            Task { await endRecording() }
        default:
            break
        }
    }

    func finish() {
        guard case .paused = state else { return }
        Task { await completeDream() }
    }
    
    func remove(_ segment: AudioSegment) {
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
                    if !cleaned.isEmpty {
                        // naïve approach: tack the text onto the draft title
                        // You might instead store per-segment subtitles.
                        title = (title + " " + cleaned).trimmingCharacters(in: .whitespaces)
                    }
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
            state = .paused
        } catch {
            state = .failed("Stop error: \(error.localizedDescription)")
        }
    }

    private func completeDream() async {
        guard let id = dreamID else { return }
        state = .saving
        do {
            let safeTitle = title.trimmingCharacters(in: .whitespaces)
            if !safeTitle.isEmpty {
                try await renamer(dreamID: id, newTitle: safeTitle)   
            }
            
            try await done(dreamID: id)
            reset()
            state = .saved

            // banner timeout
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                if case .saved = state { state = .idle }
            }
        } catch {
            state = .failed("Save error: \(error.localizedDescription)")
        }
    }
    
    private func refreshSegments() async throws {
        guard let id = dreamID else { return }
        segments = try await querySegments(id)
    }

    private func reset() {
        dreamID = nil
        handle  = nil
        order   = 0
        segments.removeAll()
        title = ""
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
