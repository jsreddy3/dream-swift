//
//  dreamApp.swift
//

import SwiftUI
import Features
import Infrastructure
import DomainLogic
import BackgroundTasks
import Configuration
import GoogleSignIn

// MARK: – Background-sync helper
func scheduleDreamSync() {
    let req = BGProcessingTaskRequest(identifier: "com.dreamfinder.sync")
    req.requiresNetworkConnectivity = true
    req.requiresExternalPower      = false
    try? BGTaskScheduler.shared.submit(req)
}

private let sharedAuth = AuthStore()

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
    private let auth = sharedAuth

    // `@Observable` class → store with @State
    @State private var captureVM: CaptureViewModel
    @State private var libraryVM: DreamLibraryViewModel
    @StateObject private var authBridge = AuthBridge(sharedAuth)   // ← no 'self'

    
    // ──────────────────────────────────────────────────────────────
    //  Init
    // ──────────────────────────────────────────────────────────────
    init() {
        GIDSignIn.sharedInstance.configuration =
                GIDConfiguration(clientID: Config.googleClientID)
        
        Task { @MainActor in
                try? await sharedAuth.ensureGoogleUserLoaded()
            }
        
        let local  = FileDreamStore()
        let remote = RemoteDreamStore(
            baseURL: Config.apiBase,
            auth: sharedAuth)
        let s      = SyncingDreamStore(local: local, remote: remote)
        store = s                                   // ← ‘let’ member initialised

        // build the VMs without touching self
        let vm = CaptureViewModel(recorder: recorder, store: s)
        _captureVM = State(wrappedValue: vm)        // ← no autoclosure capture
        
        let libVM = DreamLibraryViewModel(store: s)
        _libraryVM = State(wrappedValue: libVM)
    }

        // MARK: UI scene -----------------------------------------------------
        @Environment(\.scenePhase) private var phase

    var body: some Scene {
            WindowGroup {
                RootView(auth: authBridge, captureVM: captureVM, libraryVM: libraryVM)
                    .font(.custom("Avenir", size: 17))
                    .onAppear {
                        appDelegate.configure(store: store)
                        Task { await store.drain() }                   // <─ run once, right now
                        Task { await libraryVM.refresh() }             // <─ preload library data


                    }
            }
            .onChange(of: phase) { oldPhase, newPhase in
                if newPhase == .active {
                    Task { await store.drain() }
                } else if newPhase == .background {
                    scheduleDreamSync()                        // your existing code
                }
            }
        }
}
