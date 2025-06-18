// DomainLogic/Sources/DomainLogic/StopCaptureDream.swift
import Foundation
import CoreModels

public struct StopCaptureDream: Sendable {
    private let recorder: AudioRecorder
    private let store: DreamStore
    public init(recorder: AudioRecorder, store: DreamStore) {
        self.recorder = recorder
        self.store = store
    }

    public func callAsFunction(dreamID: UUID,
                               handle: RecordingHandle,
                               order: Int) async throws {
        // 1. Finish the recording and obtain the file info
        let completed = try await recorder.stop(handle)

        // 2. Convert it into a domain AudioSegment
        let segment = AudioSegment(id: completed.segmentID,
                                   filename: completed.filename,
                                   duration: completed.duration,
                                   order: order)

        // 3. Persist the new segment inside the dream
        try await store.appendSegment(dreamID: dreamID, segment: segment)
    }
}

