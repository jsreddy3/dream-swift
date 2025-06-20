// dreamApp.swift
import SwiftUI
import Features                 // now finds the right ContentView
import Infrastructure
import DomainLogic

@main
struct dreamApp: App {
    private let recorder = AudioRecorderActor()
    private let store = RemoteDreamStore(baseURL: URL(string: "http://192.168.0.149:8000")!)


    var body: some Scene {
        WindowGroup {
            ContentView(
                viewModel: CaptureViewModel(recorder: recorder, store: store)
            )
        }
    }
}

