// DomainLogic/Sources/DomainLogic/StartAdditionalSegment.swift
import Foundation
import CoreModels

public struct StartAdditionalSegment: Sendable {
    private let recorder: AudioRecorder
    private let store: DreamStore
    public init(recorder: AudioRecorder, store: DreamStore) {
        self.recorder = recorder
        self.store = store
    }

    public func callAsFunction(dreamID: UUID) async throws -> RecordingHandle {
        let handle = try await recorder.begin()
        return handle                                            // caller holds it until stop()
    }
}
