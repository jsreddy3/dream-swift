// dreamApp.swift
import SwiftUI
import Features
import Infrastructure
import DomainLogic

@main
struct dreamApp: App {

    // concrete singletons for the whole run
    private let recorder: AudioRecorderActor
    private let store:    SyncingDreamStore

    /// Build the object graph once, in the right sequence.
    init() {
        self.recorder = AudioRecorderActor()

        let file   = FileDreamStore()
        let remote = RemoteDreamStore(
            baseURL: URL(string: "http://192.168.0.149:8000")!
        )
        self.store = SyncingDreamStore(local: file, remote: remote)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                viewModel: CaptureViewModel(recorder: recorder, store: store)
            )
        }
    }
}
