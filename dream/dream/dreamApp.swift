// dreamApp.swift
import SwiftUI
import Features                 // now finds the right ContentView
import Infrastructure
import DomainLogic

@main
struct dreamApp: App {
    private let recorder = AudioRecorderActor()
    private let store    = FileDreamStore()

    var body: some Scene {
        WindowGroup {
            ContentView(
                viewModel: CaptureViewModel(recorder: recorder, store: store)
            )
        }
    }
}

