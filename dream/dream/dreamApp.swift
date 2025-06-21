//  dreamApp.swift
import SwiftUI
import Features
import Infrastructure
import DomainLogic
import BackgroundTasks

/// One helper shared by both files.  Lives at top level to avoid `self` captures.
func scheduleDreamSync() {
    let request = BGProcessingTaskRequest(identifier: "com.dreamfinder.sync")
    request.requiresNetworkConnectivity = true
    request.requiresExternalPower = false
    try? BGTaskScheduler.shared.submit(request)       // duplicate-request errors are fine
}

@main
struct dreamApp: App {

    // MARK: singletons
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let recorder = AudioRecorderActor()
    private let store:    SyncingDreamStore

    init() {
        let file   = FileDreamStore()
        let remote = RemoteDreamStore(
            baseURL: URL(string: "http://10.0.0.195:8000")!
        )
        store = SyncingDreamStore(local: file, remote: remote)
        appDelegate.configure(store: store)
    }

    // MARK: UI scene
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            ContentView(
                viewModel: CaptureViewModel(recorder: recorder, store: store)
            )
        }
        .onChange(of: phase) {                      // no ‘newPhase’ param
            if phase == .background {               // just read the env var
                scheduleDreamSync()
            }
        }
    }
}
