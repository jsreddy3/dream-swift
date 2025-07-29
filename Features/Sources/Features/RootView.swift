//  RootView.swift     (Features)

import SwiftUI
import Infrastructure          // for AuthStore, SyncingDreamStore
import DomainLogic             // for CaptureViewModel
import CoreModels              // for shared types
import Configuration           // for Config.forceOnboardingForTesting

// MARK: - Color Palette
private extension Color {
    static let campfireBg   = Color(red: 33/255, green: 24/255, blue: 21/255)
    static let campfireCard = Color(red: 54/255, green: 37/255, blue: 32/255)
    static let ember        = Color(red: 255/255, green: 145/255, blue: 0/255)
}

@MainActor                     // safe because it only talks to SwiftUI
public final class AuthBridge: ObservableObject {
    private let backend: AuthStore
    let store: SyncingDreamStore?  // Made internal for access
    @Published var isAuthenticating = false   // ⟵ add this
    @Published var jwt: String?          // UI can react to this
    @Published var needsOnboarding = false    // ⟵ onboarding state
    @Published var isCheckingOnboarding = false  // ⟵ loading state for onboarding check

    public init(_ backend: AuthStore, store: SyncingDreamStore? = nil) {
        self.backend = backend
        self.store = store
        jwt = backend.jwt                // whatever is in the key-chain
        
        // If user has JWT, we need to check onboarding status before showing main UI
        if jwt != nil {
            isCheckingOnboarding = true
            Task { 
                await checkOnboardingNeeded()
                await MainActor.run {
                    isCheckingOnboarding = false
                }
            }
        }
    }
    

    func signIn(presenting vc: UIViewController) async {
        await MainActor.run { isAuthenticating = true }

        // • The defer must not contain 'await'.
        // • Wrapping the mutation in Task { @MainActor in … } is allowed.
        defer { Task { @MainActor in self.isAuthenticating = false } }

        do {
            try await backend.signIn(from: vc)          // Google + backend
            await MainActor.run { 
                jwt = backend.jwt                       // immediate UI update
                isCheckingOnboarding = true             // start onboarding check
            }
            
            // Check if user needs onboarding
            await checkOnboardingNeeded()
            await MainActor.run {
                isCheckingOnboarding = false           // onboarding check complete
            }
        } catch {
            print("Google sign-in failed: \(error)")
        }
    }
    
    private func checkOnboardingNeeded() async {
        print("🔍 [ONBOARDING DEBUG] Starting onboarding check...")
        
        guard let store = store else { 
            print("🔍 [ONBOARDING DEBUG] No store available")
            let forceOnboarding = Config.forceOnboardingForTesting
            let hasCompleted = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
            
            print("🔍 [ONBOARDING DEBUG] Feature flag forceOnboardingForTesting: \(forceOnboarding)")
            print("🔍 [ONBOARDING DEBUG] UserDefaults hasCompletedOnboarding: \(hasCompleted)")
            
            // Without store, assume new user needs onboarding unless they've explicitly completed it
            let shouldShow = forceOnboarding || !hasCompleted
            await MainActor.run {
                needsOnboarding = shouldShow
                print("🔍 [ONBOARDING DEBUG] Set needsOnboarding to: \(needsOnboarding)")
            }
            return 
        }
        
        do {
            let dreams = try await store.allDreams()
            
            // Check if the key actually exists
            let keyExists = UserDefaults.standard.object(forKey: "hasCompletedOnboarding") != nil
            let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
            
            print("🔍 [ONBOARDING DEBUG] Dreams count: \(dreams.count)")
            print("🔍 [ONBOARDING DEBUG] Dreams isEmpty: \(dreams.isEmpty)")
            print("🔍 [ONBOARDING DEBUG] UserDefaults key exists: \(keyExists)")
            print("🔍 [ONBOARDING DEBUG] UserDefaults hasCompletedOnboarding: \(hasCompletedOnboarding)")
            
            // Feature flag override for testing
            let forceOnboarding = Config.forceOnboardingForTesting
            print("🔍 [ONBOARDING DEBUG] Feature flag forceOnboardingForTesting: \(forceOnboarding)")
            
            // Normal logic: show onboarding if no dreams AND user hasn't completed onboarding
            let normalLogicShouldShow = dreams.isEmpty && !hasCompletedOnboarding
            
            // Final decision: force flag OR normal logic
            let shouldShowOnboarding = forceOnboarding || normalLogicShouldShow
            
            print("🔍 [ONBOARDING DEBUG] Normal logic would show: \(normalLogicShouldShow)")
            print("🔍 [ONBOARDING DEBUG] Final decision - Should show onboarding: \(shouldShowOnboarding)")
            
            await MainActor.run {
                needsOnboarding = shouldShowOnboarding
                print("🔍 [ONBOARDING DEBUG] Set needsOnboarding to: \(needsOnboarding)")
            }
        } catch {
            print("🔍 [ONBOARDING DEBUG] Failed to check dreams: \(error)")
            let forceOnboarding = Config.forceOnboardingForTesting
            let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
            
            print("🔍 [ONBOARDING DEBUG] Fallback - Feature flag forceOnboardingForTesting: \(forceOnboarding)")
            print("🔍 [ONBOARDING DEBUG] Fallback - UserDefaults hasCompletedOnboarding: \(hasCompletedOnboarding)")
            
            let shouldShow = forceOnboarding || !hasCompletedOnboarding
            await MainActor.run {
                needsOnboarding = shouldShow
                print("🔍 [ONBOARDING DEBUG] Fallback - Set needsOnboarding to: \(shouldShow)")
            }
        }
    }
    
    @MainActor
    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        needsOnboarding = false
    }
    
    @MainActor
    func resetOnboardingForTesting() {
        print("🔍 [DEBUG] Resetting onboarding flag for testing")
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        needsOnboarding = true
    }
    
    
    @MainActor
    func signOut() {
        Task {                                  // hop off the main thread
            await backend.signOut()
            await MainActor.run { jwt = nil }   // make UI react instantly
        }
    }
}

public struct RootView: View {                      // ← public
    @ObservedObject public var auth: AuthBridge
    public let captureVM: CaptureViewModel
    public let libraryVM: DreamLibraryViewModel

    public init(auth: AuthBridge, captureVM: CaptureViewModel, libraryVM: DreamLibraryViewModel) {
        self.auth = auth
        self.captureVM = captureVM
        self.libraryVM = libraryVM
    }

    public var body: some View {
        if auth.jwt == nil {
            ZStack {                               // keep hierarchy stable
                SignInView(auth: auth)
                    .opacity(auth.isAuthenticating ? 0 : 1)   // ← hide button

                if auth.isAuthenticating {
                    Color.black.opacity(0.2).ignoresSafeArea() // dim background
                    ProgressView("Signing in…")
                        .padding()
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        } else if auth.isCheckingOnboarding {
            // Show loading while determining onboarding status
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 24) {
                    LoopingVideoView(named: "campfire_fullrange")
                        .frame(width: 120, height: 120)
                        .cornerRadius(20)
                        .opacity(0.8)
                    ProgressView("Loading…")
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
            }
        } else if auth.needsOnboarding {
            OnboardingPlaceholderView(auth: auth)
        } else {
            if let store = auth.store {
                MainTabView(
                    captureVM: captureVM, 
                    libraryVM: libraryVM,
                    store: store
                )
                .environmentObject(auth)
            } else {
                // Fallback if no store available
                ContentView(viewModel: captureVM, libraryViewModel: libraryVM)
                    .environmentObject(auth)
            }
        }
    }
}

struct SignInView: View {
    @ObservedObject var auth: AuthBridge
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            // Campfire video background
            GeometryReader { geometry in
                LoopingVideoView(named: "campfire_fullrange")
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .opacity(0.6)
            }
            .ignoresSafeArea()
            
            // Dark overlay for readability
            Color.black.opacity(0.4).ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Welcome content
                VStack(spacing: 24) {
                    // App title/logo area
                    VStack(spacing: 8) {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 48))
                            .foregroundColor(Color.ember)
                        
                        Text("Dream")
                            .font(.custom("Avenir-Heavy", size: 42))
                            .foregroundColor(.white)
                    }
                    
                    // Welcome message
                    VStack(spacing: 16) {
                        Text("Capture the wisdom of your sleep")
                            .font(.custom("Avenir-Medium", size: 24))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text("Record your dreams the moment you wake,\nand discover their hidden meanings")
                            .font(.custom("Avenir-Book", size: 18))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                }
                
                Spacer()
                
                // Sign in button
                VStack(spacing: 16) {
                    GoogleSignInButton(auth: auth)
                        .padding(.horizontal, 24)
                    
                    Text("Your dreams are private and secure")
                        .font(.custom("Avenir-Book", size: 14))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.bottom, 60)
            }
            .padding(.horizontal, 32)
        }
    }
}

struct GoogleSignInButton: View {
    @ObservedObject var auth: AuthBridge
    
    var body: some View {
        Button {
            // Get the current window's root view controller
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                Task { await auth.signIn(presenting: rootViewController) }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "globe")
                    .font(.system(size: 18, weight: .medium))
                
                Text("Continue with Google")
                    .font(.custom("Avenir-Medium", size: 18))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 27)
                    .fill(Color.ember)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Beautiful Onboarding View
struct OnboardingPlaceholderView: View {
    @ObservedObject var auth: AuthBridge
    @State private var currentPage = 0
    @State private var contentOpacity = 0.0
    
    private let totalPages = 4
    
    var body: some View {
        ZStack {
            // Persistent campfire background
            GeometryReader { geometry in
                LoopingVideoView(named: "campfire_fullrange")
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .opacity(0.4)
            }
            .ignoresSafeArea()
            
            // Dark overlay for readability
            Color.black.opacity(0.5).ignoresSafeArea()
            
            VStack {
                // Skip button + Debug info
                HStack {
                    // Debug info (remove for production)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("🔍 DEBUG")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        Text("Flag: \(Config.forceOnboardingForTesting ? "ON" : "OFF")")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                        Text("Page: \(currentPage + 1)/\(totalPages)")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                    }
                    .padding(.leading, 24)
                    .padding(.top, 20)
                    
                    Spacer()
                    
                    Button("Skip") {
                        auth.completeOnboarding()
                    }
                    .font(.custom("Avenir-Book", size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.top, 20)
                    .padding(.trailing, 24)
                }
                
                Spacer()
                
                // Content that fades
                OnboardingContent(page: currentPage, auth: auth)
                    .opacity(contentOpacity)
                
                Spacer()
                
                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.ember : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut(duration: 0.3), value: currentPage)
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .overlay(
            // Left/Right tap zones
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Left half - go back
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            print("🔍 [TAP DEBUG] Left tap - going to previous page")
                            goToPreviousPage()
                        }
                    
                    // Right half - go forward
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            print("🔍 [TAP DEBUG] Right tap - advancing to next page")
                            advanceToNextPage()
                        }
                }
            }
        )
        .onAppear {
            withAnimation(.easeIn(duration: 1.0)) {
                contentOpacity = 1.0
            }
        }
    }
    
    private func advanceToNextPage() {
        print("🔍 [NAV DEBUG] advanceToNextPage called, currentPage: \(currentPage), totalPages: \(totalPages)")
        
        if currentPage < totalPages - 1 {
            print("🔍 [NAV DEBUG] Advancing from page \(currentPage) to \(currentPage + 1)")
            withAnimation(.easeInOut(duration: 0.8)) {
                contentOpacity = 0.0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                currentPage += 1
                withAnimation(.easeInOut(duration: 0.8)) {
                    contentOpacity = 1.0
                }
            }
        } else {
            print("🔍 [NAV DEBUG] On last page, completing onboarding")
            auth.completeOnboarding()
        }
    }
    
    private func goToPreviousPage() {
        print("🔍 [NAV DEBUG] goToPreviousPage called, currentPage: \(currentPage)")
        
        // Only go back if we're not on the first page
        guard currentPage > 0 else { 
            print("🔍 [NAV DEBUG] Already on first page, can't go back")
            return 
        }
        
        print("🔍 [NAV DEBUG] Going back from page \(currentPage) to \(currentPage - 1)")
        withAnimation(.easeInOut(duration: 0.8)) {
            contentOpacity = 0.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            currentPage -= 1
            withAnimation(.easeInOut(duration: 0.8)) {
                contentOpacity = 1.0
            }
        }
    }
    
}

// MARK: - Onboarding Content
struct OnboardingContent: View {
    let page: Int
    let auth: AuthBridge
    @State private var textOpacity = 0.0
    
    var body: some View {
        VStack(spacing: 32) {
            switch page {
            case 0:
                OnboardingScreen1()
            case 1:
                OnboardingScreen2()
            case 2:
                OnboardingScreen3()
            case 3:
                OnboardingScreen4(auth: auth)
            default:
                EmptyView()
            }
        }
        .opacity(textOpacity)
        .onAppear {
            withAnimation(.easeIn(duration: 1.2)) {
                textOpacity = 1.0
            }
        }
        .onChange(of: page) { _ in
            textOpacity = 0.0
            withAnimation(.easeIn(duration: 1.2).delay(0.2)) {
                textOpacity = 1.0
            }
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - Individual Screens
struct OnboardingScreen1: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 64))
                .foregroundColor(Color.ember)
            
            VStack(spacing: 16) {
                Text("Dreams hold latent magic")
                    .font(.custom("Avenir-Heavy", size: 32))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Every night, your mind weaves stories only you can tell—filled with hidden wisdom, memories, and pieces of yourself waiting to be discovered.")
                    .font(.custom("Avenir-Book", size: 18))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
    }
}

struct OnboardingScreen2: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 64))
                .foregroundColor(Color.ember)
            
            VStack(spacing: 16) {
                Text("Your brain dreams for 2 hours every night")
                    .font(.custom("Avenir-Heavy", size: 28))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Studies show people who record their dreams report 23% better self-awareness and emotional processing.")
                    .font(.custom("Avenir-Medium", size: 18))
                    .foregroundColor(Color.ember.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                
                Text("Dreams help consolidate memories and work through emotions while you sleep.")
                    .font(.custom("Avenir-Book", size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
    }
}

struct OnboardingScreen3: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 64))
                .foregroundColor(Color.ember)
            
            VStack(spacing: 16) {
                Text("Dreams are stories only your brain can tell")
                    .font(.custom("Avenir-Heavy", size: 28))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("82% of couples who share dreams report feeling more emotionally connected.")
                    .font(.custom("Avenir-Medium", size: 18))
                    .foregroundColor(Color.ember.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                
                Text("For centuries, humans have gathered around fires to share the visions of sleep—intimate glimpses into our inner worlds.")
                    .font(.custom("Avenir-Book", size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
    }
}

struct OnboardingScreen4: View {
    let auth: AuthBridge
    
    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "star.circle")
                .font(.system(size: 64))
                .foregroundColor(Color.ember)
            
            VStack(spacing: 16) {
                Text("Ready to unlock your inner wisdom?")
                    .font(.custom("Avenir-Heavy", size: 28))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Record your dreams anytime—morning, midnight, or whenever inspiration strikes. We'll help you discover patterns and meanings.")
                    .font(.custom("Avenir-Book", size: 18))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            Button("Start Your Dream Journey") {
                auth.completeOnboarding()
            }
            .font(.custom("Avenir-Medium", size: 18))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 27)
                    .fill(Color.ember)
            )
            .padding(.horizontal, 24)
            .padding(.top, 16)
        }
    }
}
