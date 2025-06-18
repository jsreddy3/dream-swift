import SwiftUI
import DomainLogic          // StartCaptureDream, StopCaptureDream, CompleteDream
import Infrastructure       // AudioRecorderActor, FileDreamStore

@MainActor
public final class CaptureViewModel: ObservableObject {

    // Dependencies
    private let startUseCase: StartCaptureDream
    private let stopUseCase: StopCaptureDream
    private let doneUseCase: CompleteDream
    private let contUseCase: StartAdditionalSegment

    // UI state
    @Published var isRecording = false
    @Published var statusText  = "Ready"
    
    var hasOpenDream: Bool { currentDreamID != nil }

    // Internals
    private var currentDreamID: UUID?
    private var currentHandle: RecordingHandle?
    private var segmentOrder  = 0

    public init(recorder: AudioRecorderActor, store: FileDreamStore) {
        self.startUseCase = StartCaptureDream(recorder: recorder, store: store)
        self.stopUseCase  = StopCaptureDream(recorder: recorder, store: store)
        self.doneUseCase  = CompleteDream(store: store)
        self.contUseCase = StartAdditionalSegment(recorder: recorder, store: store)
    }

    func start() {
        Task {
            do {
                if currentDreamID == nil {                         // first segment
                    let (id, handle) = try await startUseCase()
                    currentDreamID = id
                    currentHandle  = handle
                } else {                                           // more segments
                    currentHandle = try await contUseCase(
                        dreamID: currentDreamID!
                    )
                }
                isRecording = true
                statusText  = "Recording…"
            } catch {
                statusText = "Mic error: \(error.localizedDescription)"
            }
        }
    }


    func stop() {
        guard let id = currentDreamID, let handle = currentHandle else { return }
        Task {
            do {
                try await stopUseCase(dreamID: id, handle: handle, order: segmentOrder)
                segmentOrder += 1
                isRecording   = false
                statusText    = "Paused"
            } catch {
                statusText = "Stop error: \(error.localizedDescription)"
            }
        }
    }

    func done() {
        guard let id = currentDreamID else { return }
        Task {
            do {
                try await doneUseCase(dreamID: id)
                reset()
                statusText = "Saved ✅"
            } catch {
                statusText = "Save error: \(error.localizedDescription)"
            }
        }
    }

    private func reset() {
        currentDreamID = nil
        currentHandle  = nil
        segmentOrder   = 0
        isRecording    = false
    }
}
