import SwiftUI
import DomainLogic          // StartCaptureDream, StopCaptureDream, CompleteDream
import Infrastructure       // AudioRecorderActor, FileDreamStore
import CoreModels

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
final class CaptureViewModel {
    let store: FileDreamStore            // ← expose for Library use

    private let start: StartCaptureDream
    private let stop: StopCaptureDream
    private let done: CompleteDream
    private let cont: StartAdditionalSegment
    private let querySegments: (UUID) async throws -> [AudioSegment]
    private let deleteSegment: (UUID, UUID) async throws -> Void

    var state: CaptureState = .idle          // drives the entire UI
    var segments: [AudioSegment] = []              // drives the on-screen list

    private var dreamID: UUID?
    private var handle: RecordingHandle?
    private var order = 0

    init(recorder: AudioRecorderActor, store: FileDreamStore) {
        self.store = store
        start = StartCaptureDream(recorder: recorder, store: store)
        stop  = StopCaptureDream(recorder: recorder, store: store)
        done  = CompleteDream(store: store)
        cont  = StartAdditionalSegment(recorder: recorder, store: store)
        
        querySegments = { try await store.segments(dreamID: $0) }
        deleteSegment = { try await store.removeSegment(dreamID: $0, segmentID: $1) }
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

    private func endRecording()   async {
        guard let id = dreamID, let h = handle else { return }
        do {
            try await stop(dreamID: id, handle: h, order: order)
            order += 1
            try await refreshSegments()                      // pull authoritative array
            state = .paused
        } catch {
            state = .failed("Stop error: \(error.localizedDescription)")
        }
    }

    private func completeDream() async {
        guard let id = dreamID else { return }
        state = .saving
        do {
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
    }
}
