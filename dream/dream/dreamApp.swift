//
//  dreamApp.swift
//

import SwiftUI
import Features
import Infrastructure
import DomainLogic
import BackgroundTasks

// MARK: – Background-sync helper
func scheduleDreamSync() {
    let req = BGProcessingTaskRequest(identifier: "com.dreamfinder.sync")
    req.requiresNetworkConnectivity = true
    req.requiresExternalPower      = false
    try? BGTaskScheduler.shared.submit(req)
}

// MARK: – App entry point
@main
struct DreamApp: App {
    
    // ──────────────────────────────────────────────────────────────
    //  Singletons
    // ──────────────────────────────────────────────────────────────
    @UIApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate
    
    private let recorder = AudioRecorderActor()
    private let store:    SyncingDreamStore
    
    // `@Observable` class → store with @State
    @State private var captureVM: CaptureViewModel
    
    // ──────────────────────────────────────────────────────────────
    //  Init
    // ──────────────────────────────────────────────────────────────
    init() {
        // build the data layer first
        let local  = FileDreamStore()
       let remote = RemoteDreamStore(baseURL: URL(string: "http://10.0.0.195:8000")!)
        //  let remote = RemoteDreamStore(baseURL: URL(string: "http://192.168.0.149:8000")!)
        let s      = SyncingDreamStore(local: local, remote: remote)
        store = s
        
        // now the view-model
        _captureVM = State(
            initialValue: CaptureViewModel(recorder: recorder, store: s)
        )
        
        // *after* every stored property is ready, it's safe to touch `self`
        appDelegate.configure(store: s)
    }
    
    // ──────────────────────────────────────────────────────────────
    //  UI scene
    // ──────────────────────────────────────────────────────────────────
    @Environment(\.scenePhase) private var phase
    
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: captureVM)
                .font(.custom("Avenir", size: 17))
                .onOpenURL { url in
                    guard url.scheme == "dreamrec",
                          url.host   == "capture" else { return }
                }
        }
        .onChange(of: phase) {
            if phase == .background {
                scheduleDreamSync()
            }
        }
    }
}
