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
    private let profileStore: RemoteProfileStore

    // `@Observable` class → store with @State
    @State private var captureVM: CaptureViewModel
    @State private var libraryVM: DreamLibraryViewModel
    @State private var authBridge: AuthBridge

    
    // ──────────────────────────────────────────────────────────────
    //  Init
    // ──────────────────────────────────────────────────────────────
    init() {
        GIDSignIn.sharedInstance.configuration =
                GIDConfiguration(clientID: Config.googleClientID)
        
        Task { @MainActor in
                try? await sharedAuth.ensureGoogleUserLoaded()
            }
        
        // Initialize analytics
        #if DEBUG
        // Use same key for debug builds (you can change this to a test project later)
        AnalyticsService.shared.configure(apiKey: "phc_AYQdBPNqxWZoayFaPpFzaPeg3XKZ8rOU3resSW6jj17")
        #else
        // Use production key for release builds
        AnalyticsService.shared.configure(apiKey: "phc_AYQdBPNqxWZoayFaPpFzaPeg3XKZ8rOU3resSW6jj17")
        #endif
        
        let local  = FileDreamStore()
        let remote = RemoteDreamStore(
            baseURL: Config.apiBase,
            auth: sharedAuth)
        let s      = SyncingDreamStore(local: local, remote: remote)
        store = s                                   // ← 'let' member initialised
        
        // Initialize profile store
        profileStore = RemoteProfileStore(
            baseURL: Config.apiBase,
            auth: sharedAuth
        )

        // build the VMs without touching self
        let vm = CaptureViewModel(recorder: recorder, store: s)
        _captureVM = State(wrappedValue: vm)        // ← no autoclosure capture
        
        let libVM = DreamLibraryViewModel(store: s)
        _libraryVM = State(wrappedValue: libVM)
        
        let authBr = AuthBridge(sharedAuth, store: s)
        _authBridge = State(wrappedValue: authBr)
    }

        // MARK: UI scene -----------------------------------------------------
        @Environment(\.scenePhase) private var phase

    var body: some Scene {
            WindowGroup {
                RootView(auth: authBridge, captureVM: captureVM, libraryVM: libraryVM, profileStore: profileStore)
                    .font(DesignSystem.Typography.defaultFont())
                    .onAppear {
                        appDelegate.configure(store: store)
                        Task { await store.drain() }                   // <─ run once, right now
                        Task { await libraryVM.refresh() }             // <─ preload library data
                        
                        // Track app launch
                        AnalyticsService.shared.track(.appLaunched, properties: [
                            "has_jwt": authBridge.jwt != nil,
                            "launch_type": authBridge.jwt != nil ? "returning" : "new"
                        ])
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
