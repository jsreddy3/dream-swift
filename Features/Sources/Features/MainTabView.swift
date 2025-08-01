import SwiftUI
import UIKit                    // UISelectionFeedbackGenerator
import Infrastructure
import DomainLogic
import CoreModels

// MARK: - Main Tab View

public struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var captureVM: CaptureViewModel
    @State private var libraryVM: DreamLibraryViewModel
    @EnvironmentObject private var auth: AuthBridge
    @StateObject private var tabCoordinator = TabCoordinator()
    
    private let store: DreamStore
    private let profileStore: RemoteProfileStore
    
    public init(captureVM: CaptureViewModel, libraryVM: DreamLibraryViewModel, store: DreamStore, profileStore: RemoteProfileStore) {
        self._captureVM = State(initialValue: captureVM)
        self._libraryVM = State(initialValue: libraryVM)
        self.store = store
        self.profileStore = profileStore
        
        // Force TabView background to be transparent
        UITabBar.appearance().isTranslucent = true
        UITabBar.appearance().backgroundImage = UIImage()
        UITabBar.appearance().shadowImage = UIImage()
    }
    
    public var body: some View {
        TabView(selection: $tabCoordinator.selectedTab) {
            // Profile Tab
            ProfileView(profileStore: profileStore, dreamStore: store)
                .tabItem {
                    Label("Profile", systemImage: "moon.stars.fill")
                }
                .tag(0)
            
            // Record Tab
            ContentView(viewModel: captureVM, libraryViewModel: libraryVM)
                .environmentObject(tabCoordinator)
                .tabItem {
                    Label("Record", systemImage: "waveform.circle.fill")
                }
                .tag(1)
            
            // Library Tab
            NavigationStack {
                DreamLibraryView(viewModel: libraryVM)
                    .environmentObject(tabCoordinator)
                    .onAppear {
                        // Refresh when tab becomes visible and we've saved a dream
                        if captureVM.state == .saved {
                            Task { await libraryVM.refresh() }
                        }
                    }
            }
            .tabItem {
                Label("Library", systemImage: "books.vertical.fill")
            }
            .tag(2)
        }
        .background(Color.clear)
        .tint(DesignSystem.Colors.ember)
        .onChange(of: tabCoordinator.selectedTab) { newTab in
            // Provide subtle haptic feedback for tab switches
            // Only triggers on actual tab changes, not repeated taps
            let selectionFeedback = UISelectionFeedbackGenerator()
            selectionFeedback.selectionChanged()
        }
        .onAppear {
            // Make TabView background transparent
            UITabBar.appearance().isTranslucent = true
            UITabBar.appearance().backgroundImage = UIImage()
            UITabBar.appearance().shadowImage = UIImage()
            UITabBar.appearance().backgroundColor = .clear
            // Customize tab bar appearance
            let appearance = UITabBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = UIColor(DesignSystem.Colors.backgroundPrimary.opacity(0.7))
            
            // Set the appearance for all states
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}