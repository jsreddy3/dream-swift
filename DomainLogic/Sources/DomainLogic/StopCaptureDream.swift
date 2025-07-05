// DomainLogic/Sources/DomainLogic/StopCaptureDream.swift

import Foundation
import CoreModels

/// Finishes an in-progress audio recording, persists the resulting clip,
/// and returns the canonical `Segment` object.
public struct StopCaptureDream: Sendable {
    private let recorder: AudioRecorder
    private let store: DreamStore

    public init(recorder: AudioRecorder, store: DreamStore) {
        self.recorder = recorder
        self.store = store
    }

    public func callAsFunction(
        dreamID: UUID,
        handle: RecordingHandle,
        order: Int
    ) async throws -> Segment {

        // 1. Finish the recording and obtain the on-disk info.
        let completed = try await recorder.stop(handle)

        // 2. Wrap it in a domain-level Segment (audio modality).
        let segment = Segment.audio(id: completed.segmentID,
                                    filename: completed.filename,
                                    duration: completed.duration,
                                    order: order)

        // 3. Persist the new segment inside the dream.
        try await store.appendSegment(dreamID: dreamID, segment: segment)

        return segment
    }
}
