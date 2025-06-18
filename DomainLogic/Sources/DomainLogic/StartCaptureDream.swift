//
//  StartCaptureDream.swift
//  DomainLogic
//
//  Created by Jaiden Reddy on 6/18/25.
//
import Foundation
import CoreModels

public struct StartCaptureDream: Sendable {
    private let recorder: AudioRecorder
    private let store: DreamStore
    public init(recorder: AudioRecorder, store: DreamStore) {
        self.recorder = recorder
        self.store = store
    }

    public func callAsFunction() async throws -> (dreamID: UUID, handle: RecordingHandle) {
        let handle = try await recorder.begin()
        let dream = Dream(id: UUID(),
                          created: Date(),
                          title: "Untitled Dream",
                          transcript: nil)
        try await store.insertNew(dream)
        return (dream.id, handle)
    }
}
