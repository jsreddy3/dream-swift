import SwiftUI
import Infrastructure
import DomainLogic
import CoreModels

// MARK: - Main Tab View

public struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var captureVM: CaptureViewModel
    @State private var libraryVM: DreamLibraryViewModel
    @EnvironmentObject private var auth: AuthBridge
    
    private let store: DreamStore
    
    public init(captureVM: CaptureViewModel, libraryVM: DreamLibraryViewModel, store: DreamStore) {
        self._captureVM = State(initialValue: captureVM)
        self._libraryVM = State(initialValue: libraryVM)
        self.store = store
        
        // Force TabView background to be transparent
        UITabBar.appearance().isTranslucent = true
        UITabBar.appearance().backgroundImage = UIImage()
        UITabBar.appearance().shadowImage = UIImage()
    }
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            // Profile Tab
            ProfileView(store: store)
                .tabItem {
                    Label("Profile", systemImage: "moon.stars.fill")
                }
                .tag(0)
            
            // Record Tab
            ContentView(viewModel: captureVM, libraryViewModel: libraryVM)
                .tabItem {
                    Label("Record", systemImage: "waveform.circle.fill")
                }
                .tag(1)
            
            // Library Tab
            NavigationStack {
                DreamLibraryView(viewModel: libraryVM)
            }
            .tabItem {
                Label("Library", systemImage: "books.vertical.fill")
            }
            .tag(2)
        }
        .background(Color.clear)
        .tint(DesignSystem.Colors.ember)
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