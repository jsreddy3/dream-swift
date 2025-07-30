//  RootView.swift     (Features)

import SwiftUI
import Infrastructure          // for AuthStore, SyncingDreamStore, AnalyticsService
import DomainLogic             // for CaptureViewModel
import CoreModels              // for shared types, UserPreferences, ArchetypeSuggestion
import Configuration           // for Config.forceOnboardingForTesting
import UserNotifications       // for notification permissions

// MARK: - Color Palette (Using Design System)

@MainActor                     // safe because it only talks to SwiftUI
public final class AuthBridge: ObservableObject {
    private let backend: AuthStore
    let store: SyncingDreamStore?  // Made internal for access
    @Published var isAuthenticating = false   // ⟵ add this
    @Published public var jwt: String?          // UI can react to this
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
                
                // Track successful sign in
                if let jwt = backend.jwt {
                    AnalyticsService.shared.track(.signInCompleted)
                    // TODO: Extract user ID from JWT and identify user
                    // AnalyticsService.shared.identify(userId: extractUserIdFromJWT(jwt))
                }
            }
            
            // Check if user needs onboarding
            await checkOnboardingNeeded()
            await MainActor.run {
                isCheckingOnboarding = false           // onboarding check complete
            }
        } catch {
            #if DEBUG
            print("Google sign-in failed: \(error)")
            #endif
            // Track sign in failure
            AnalyticsService.shared.track(.signInFailed, properties: [
                "error": String(describing: error)
            ])
        }
    }
    
    private func checkOnboardingNeeded() async {
        #if DEBUG
        print("🔍 [ONBOARDING DEBUG] Starting onboarding check...")
        #endif
        
        guard let store = store else { 
            #if DEBUG
            print("🔍 [ONBOARDING DEBUG] No store available")
            #endif
            let forceOnboarding = Config.forceOnboardingForTesting
            let hasCompleted = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
            
            #if DEBUG
            print("🔍 [ONBOARDING DEBUG] Feature flag forceOnboardingForTesting: \(forceOnboarding)")
            print("🔍 [ONBOARDING DEBUG] UserDefaults hasCompletedOnboarding: \(hasCompleted)")
            #endif
            
            // Without store, assume new user needs onboarding unless they've explicitly completed it
            let shouldShow = forceOnboarding || !hasCompleted
            await MainActor.run {
                needsOnboarding = shouldShow
                #if DEBUG
                print("🔍 [ONBOARDING DEBUG] Set needsOnboarding to: \(needsOnboarding)")
                #endif
            }
            return 
        }
        
        do {
            // Network timeout protection is handled in SyncingDreamStore.allDreams()
            let dreams = try await store.allDreams()
            
            // Check if the key actually exists
            let keyExists = UserDefaults.standard.object(forKey: "hasCompletedOnboarding") != nil
            let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
            
            #if DEBUG
            print("🔍 [ONBOARDING DEBUG] Dreams count: \(dreams.count)")
            print("🔍 [ONBOARDING DEBUG] Dreams isEmpty: \(dreams.isEmpty)")
            print("🔍 [ONBOARDING DEBUG] UserDefaults key exists: \(keyExists)")
            print("🔍 [ONBOARDING DEBUG] UserDefaults hasCompletedOnboarding: \(hasCompletedOnboarding)")
            #endif
            
            // Feature flag override for testing
            let forceOnboarding = Config.forceOnboardingForTesting
            #if DEBUG
            print("🔍 [ONBOARDING DEBUG] Feature flag forceOnboardingForTesting: \(forceOnboarding)")
            #endif
            
            // Normal logic: show onboarding if no dreams AND user hasn't completed onboarding
            let normalLogicShouldShow = dreams.isEmpty && !hasCompletedOnboarding
            
            // Final decision: force flag OR normal logic
            let shouldShowOnboarding = forceOnboarding || normalLogicShouldShow
            
            #if DEBUG
            print("🔍 [ONBOARDING DEBUG] Normal logic would show: \(normalLogicShouldShow)")
            print("🔍 [ONBOARDING DEBUG] Final decision - Should show onboarding: \(shouldShowOnboarding)")
            #endif
            
            await MainActor.run {
                needsOnboarding = shouldShowOnboarding
                #if DEBUG
                print("🔍 [ONBOARDING DEBUG] Set needsOnboarding to: \(needsOnboarding)")
                #endif
            }
        } catch {
            let isTimeout = (error as? PreferencesError) == .timeout
            #if DEBUG
            print("🔍 [ONBOARDING DEBUG] Failed to check dreams: \(error)")
            print("🔍 [ONBOARDING DEBUG] Error was timeout: \(isTimeout)")
            #endif
            
            let forceOnboarding = Config.forceOnboardingForTesting
            let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
            
            #if DEBUG
            print("🔍 [ONBOARDING DEBUG] Fallback - Feature flag forceOnboardingForTesting: \(forceOnboarding)")
            print("🔍 [ONBOARDING DEBUG] Fallback - UserDefaults hasCompletedOnboarding: \(hasCompletedOnboarding)")
            #endif
            
            // For timeout errors, be more conservative about showing onboarding
            let shouldShow = forceOnboarding || !hasCompletedOnboarding
            await MainActor.run {
                needsOnboarding = shouldShow
                #if DEBUG
                print("🔍 [ONBOARDING DEBUG] Fallback - Set needsOnboarding to: \(shouldShow)")
                #endif
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
        #if DEBUG
        print("🔍 [DEBUG] Resetting onboarding flag for testing")
        #endif
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        needsOnboarding = true
    }
    
    
    @MainActor
    func signOut() {
        // Track sign out
        AnalyticsService.shared.track(.signOutCompleted)
        AnalyticsService.shared.reset()  // Clear user identity
        
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
                    DesignSystem.Colors.overlayDim.ignoresSafeArea() // dim background
                    ProgressView("Signing in…")
                        .padding()
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        } else if auth.isCheckingOnboarding {
            // Show loading while determining onboarding status
            ZStack {
                // Use the standard app background for consistency
                DreamBackground()
                
                VStack(spacing: 24) {
                    // Ember circle with glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    DesignSystem.Colors.ember,
                                    DesignSystem.Colors.ember.opacity(0.3)
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 60
                            )
                        )
                        .frame(width: DesignSystem.Sizes.profileImageMedium, height: DesignSystem.Sizes.profileImageMedium)
                        .overlay(
                            Image(systemName: "moon.stars.fill")
                                .font(.system(size: 48))
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                        )
                        .shadow(color: DesignSystem.Colors.ember.opacity(0.6), radius: 30)
                    
                    ProgressView("Loading…")
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
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
            // Use the standard app background for consistency
            DreamBackground()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Welcome content
                VStack(spacing: 24) {
                    // App title/logo area
                    VStack(spacing: 8) {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(DesignSystem.Gradients.dreamGradient)
                        
                        Text("Dream")
                            .font(DesignSystem.Typography.largeTitle())
                            .foregroundStyle(DesignSystem.Gradients.dreamGradient)
                    }
                    
                    // Welcome message
                    VStack(spacing: 16) {
                        Text("Capture the wisdom of your sleep")
                            .font(DesignSystem.Typography.title3())
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .multilineTextAlignment(.center)
                        
                        Text("Record your dreams the moment you wake,\nand discover their hidden meanings")
                            .font(DesignSystem.Typography.body())
                            .foregroundColor(DesignSystem.Colors.textSecondary)
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
                        .font(DesignSystem.Typography.caption())
                        .foregroundColor(DesignSystem.Colors.textQuaternary)
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
            // Track sign in started
            AnalyticsService.shared.track(.signInStarted)
            
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
                    .font(DesignSystem.Typography.subheadline())
            }
            .foregroundColor(DesignSystem.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 27)
                    .fill(DesignSystem.Gradients.dreamGradient)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Enhanced Onboarding View with Data Collection
struct OnboardingPlaceholderView: View {
    @ObservedObject var auth: AuthBridge
    @State private var currentPage = 0
    @State private var contentOpacity = 0.0
    @State private var userPreferences = UserPreferences()
    @State private var suggestedArchetype: ArchetypeSuggestion?
    @State private var isSubmittingPreferences = false
    @State private var onboardingStartTime = Date()
    @State private var hasTrackedStart = false
    @State private var journeyTracker = OnboardingJourneyTracker()
    
    private let totalPages = 7
    
    private func getPageName(for page: Int) -> String {
        switch page {
        case 0: return "welcome"
        case 1: return "sleep_patterns"
        case 2: return "dream_patterns"
        case 3: return "goals_interests"
        case 4: return "notifications"
        case 5: return "archetype_reveal"
        case 6: return "complete"
        default: return "unknown"
        }
    }
    
    var body: some View {
        ZStack {
            // Use the standard app background for consistency
            DreamBackground()
            
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
                        AnalyticsService.shared.track(.onboardingSkipped, properties: [
                            "skipped_at_page": currentPage + 1,
                            "page_name": getPageName(for: currentPage)
                        ])
                        
                        // Track skip in journey
                        journeyTracker.trackNavigation(action: "skip", fromPage: currentPage + 1)
                        journeyTracker.completeJourney(skipped: true, skippedAtPage: currentPage + 1)
                        
                        auth.completeOnboarding()
                    }
                    .font(DesignSystem.Typography.bodySmall())
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                    .padding(.top, 20)
                    .padding(.trailing, 24)
                }
                
                Spacer()
                
                // Content that fades
                OnboardingContent(
                    page: currentPage, 
                    auth: auth,
                    userPreferences: $userPreferences,
                    suggestedArchetype: suggestedArchetype,
                    onPreferencesSubmit: submitPreferences,
                    onboardingStartTime: onboardingStartTime
                )
                .opacity(contentOpacity)
                
                Spacer()
                
                // Navigation controls
                VStack(spacing: 16) {
                    // Page indicators
                    HStack(spacing: 8) {
                        ForEach(0..<totalPages, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? AnyShapeStyle(DesignSystem.Gradients.dreamGradient) : AnyShapeStyle(DesignSystem.Colors.textPrimary.opacity(0.3)))
                                .frame(width: DesignSystem.Sizes.iconSmall, height: DesignSystem.Sizes.iconSmall)
                                .animation(.easeInOut(duration: 0.3), value: currentPage)
                        }
                    }
                    
                    // Navigation buttons
                    HStack(spacing: 24) {
                        // Previous button
                        Button {
                            #if DEBUG
                            print("🔍 [TAP DEBUG] Previous button - going to previous page")
                            #endif
                            AnalyticsService.shared.track(.onboardingButtonPrevious, properties: [
                                "from_page": currentPage + 1,
                                "from_page_name": getPageName(for: currentPage)
                            ])
                            goToPreviousPage()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .medium))
                                Text("Previous")
                                    .font(DesignSystem.Typography.caption())
                            }
                            .foregroundColor(currentPage > 0 ? DesignSystem.Colors.textSecondary : DesignSystem.Colors.textQuaternary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(DesignSystem.Gradients.emberGradient.opacity(currentPage > 0 ? 0.8 : 0.3))
                            )
                        }
                        .disabled(currentPage <= 0)
                        .buttonStyle(.plain)
                        
                        // Next/Continue button
                        Button {
                            #if DEBUG
                            print("🔍 [TAP DEBUG] Next button - advancing to next page")
                            #endif
                            // Track button tap
                            if currentPage != totalPages - 1 {
                                AnalyticsService.shared.track(.onboardingButtonNext, properties: [
                                    "from_page": currentPage + 1,
                                    "from_page_name": getPageName(for: currentPage)
                                ])
                            }
                            advanceToNextPage()
                        } label: {
                            HStack(spacing: 8) {
                                if currentPage == totalPages - 1 {
                                    Text("Complete")
                                        .font(DesignSystem.Typography.caption())
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 16, weight: .medium))
                                } else if currentPage == 4 && isSubmittingPreferences {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.textPrimary))
                                        .scaleEffect(0.8)
                                    Text("Submitting...")
                                        .font(DesignSystem.Typography.caption())
                                } else {
                                    Text("Continue")
                                        .font(DesignSystem.Typography.caption())
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 16, weight: .medium))
                                }
                            }
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(DesignSystem.Gradients.dreamGradient)
                            )
                        }
                        .disabled(isSubmittingPreferences)
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            withAnimation(.easeIn(duration: 1.0)) {
                contentOpacity = 1.0
            }
            
            // Track onboarding start
            if !hasTrackedStart {
                AnalyticsService.shared.track(.onboardingStarted)
                hasTrackedStart = true
                
                // Track initial page in journey
                journeyTracker.trackPageVisit(pageNumber: 1, pageName: getPageName(for: 0))
            }
        }
    }
    
    private func advanceToNextPage() {
        #if DEBUG
        print("🔍 [NAV DEBUG] advanceToNextPage called, currentPage: \(currentPage), totalPages: \(totalPages)")
        #endif
        
        // Track navigation in journey
        if currentPage < totalPages - 1 {
            journeyTracker.trackNavigation(action: "next", fromPage: currentPage + 1, toPage: currentPage + 2)
        }
        
        // Special handling for screen 4 (Notifications) - submit preferences and get archetype
        if currentPage == 4 && suggestedArchetype == nil {
            Task {
                await submitPreferences()
            }
            return
        }
        
        if currentPage < totalPages - 1 {
            #if DEBUG
            print("🔍 [NAV DEBUG] Advancing from page \(currentPage) to \(currentPage + 1)")
            #endif
            withAnimation(.easeInOut(duration: 0.8)) {
                contentOpacity = 0.0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                currentPage += 1
                // Track new page visit
                journeyTracker.trackPageVisit(pageNumber: currentPage + 1, pageName: getPageName(for: currentPage))
                
                withAnimation(.easeInOut(duration: 0.8)) {
                    contentOpacity = 1.0
                }
            }
        } else {
            #if DEBUG
            print("🔍 [NAV DEBUG] On last page, completing onboarding")
            #endif
            auth.completeOnboarding()
        }
    }
    
    private func submitPreferences() async {
        guard !isSubmittingPreferences else { 
            #if DEBUG
            print("🔍 [PREFERENCES] Already submitting, skipping...")
            #endif
            return 
        }
        
        #if DEBUG
        print("🔍 [PREFERENCES] Starting preference submission...")
        print("🔍 [PREFERENCES] Current preferences: \(userPreferences)")
        #endif
        isSubmittingPreferences = true
        
        do {
            // Submit preferences to backend API with timeout
            let createdPreferences = try await withTimeout(seconds: 10) {
                try await createUserPreferences(userPreferences)
            }
            #if DEBUG
            print("🔍 [PREFERENCES] Successfully created preferences")
            #endif
            
            // Get archetype suggestion with timeout  
            let archetype = try await withTimeout(seconds: 10) {
                try await suggestArchetype()
            }
            #if DEBUG
            print("🔍 [PREFERENCES] Successfully got archetype suggestion")
            #endif
            
            await MainActor.run {
                suggestedArchetype = archetype
                isSubmittingPreferences = false
                
                // Auto-advance to archetype reveal screen
                withAnimation(.easeInOut(duration: 0.8)) {
                    contentOpacity = 0.0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    currentPage = 5
                    withAnimation(.easeInOut(duration: 0.8)) {
                        contentOpacity = 1.0
                    }
                }
            }
            
            #if DEBUG
            print("✅ [PREFERENCES] Successfully submitted preferences and got archetype: \(archetype.suggestedArchetype)")
            #endif
        } catch {
            #if DEBUG
            print("❌ [PREFERENCES] Failed to submit preferences: \(error)")
            #endif
            await MainActor.run {
                isSubmittingPreferences = false
                
                // Create fallback archetype so user can continue
                suggestedArchetype = ArchetypeSuggestion(
                    suggestedArchetype: "starweaver",
                    confidence: 0.5,
                    archetypeDetails: ArchetypeDetails(
                        name: "Starweaver", 
                        symbol: "🌟", 
                        description: "A dreamer who finds patterns and wisdom in the cosmos of sleep"
                    )
                )
                
                // Auto-advance to archetype reveal screen with fallback
                withAnimation(.easeInOut(duration: 0.8)) {
                    contentOpacity = 0.0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    currentPage = 5
                    withAnimation(.easeInOut(duration: 0.8)) {
                        contentOpacity = 1.0
                    }
                }
                
                #if DEBUG
                print("⚠️ [PREFERENCES] Using fallback archetype due to API error")
                #endif
            }
        }
    }
    
    private func goToPreviousPage() {
        #if DEBUG
        print("🔍 [NAV DEBUG] goToPreviousPage called, currentPage: \(currentPage)")
        #endif
        
        // Only go back if we're not on the first page
        guard currentPage > 0 else { 
            #if DEBUG
            print("🔍 [NAV DEBUG] Already on first page, can't go back")
            #endif
            return 
        }
        
        // Track navigation in journey
        journeyTracker.trackNavigation(action: "previous", fromPage: currentPage + 1, toPage: currentPage)
        
        #if DEBUG
        print("🔍 [NAV DEBUG] Going back from page \(currentPage) to \(currentPage - 1)")
        #endif
        withAnimation(.easeInOut(duration: 0.8)) {
            contentOpacity = 0.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            currentPage -= 1
            // Track page visit (going back)
            journeyTracker.trackPageVisit(pageNumber: currentPage + 1, pageName: getPageName(for: currentPage))
            
            withAnimation(.easeInOut(duration: 0.8)) {
                contentOpacity = 1.0
            }
        }
    }
    
    // MARK: - API Functions
    private func createUserPreferences(_ preferences: UserPreferences) async throws -> UserPreferences {
        guard let store = auth.store else {
            throw PreferencesError.noAuthStore
        }
        
        // Complete the journey tracking
        journeyTracker.completeJourney(skipped: false)
        
        // Prepare the API request with both preferences and journey data
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        // First encode the preferences
        var preferencesDict = try JSONSerialization.jsonObject(
            with: try encoder.encode(preferences)
        ) as? [String: Any] ?? [:]
        
        // Add the journey data
        if let journeyDict = try? journeyTracker.exportAsDictionary() {
            preferencesDict["onboarding_journey"] = journeyDict
        }
        
        // Convert the combined dictionary to JSON data
        let data = try JSONSerialization.data(withJSONObject: preferencesDict)
        
        var request = URLRequest(url: Config.apiBase.appendingPathComponent("/api/users/me/preferences"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(auth.jwt ?? "")", forHTTPHeaderField: "Authorization")
        request.httpBody = data
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            throw PreferencesError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(UserPreferences.self, from: responseData)
    }
    
    private func suggestArchetype() async throws -> ArchetypeSuggestion {
        var request = URLRequest(url: Config.apiBase.appendingPathComponent("/api/users/me/preferences/suggest-archetype"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(auth.jwt ?? "")", forHTTPHeaderField: "Authorization")
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PreferencesError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(ArchetypeSuggestion.self, from: responseData)
    }
    
    // MARK: - Helper Functions
    private func withTimeout<T: Sendable>(seconds: Double, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            // Add the actual operation
            group.addTask {
                try await operation()
            }
            
            // Add a timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw PreferencesError.timeout
            }
            
            // Return the first result (either success or timeout)
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
}

enum PreferencesError: Error, Equatable {
    case noAuthStore
    case invalidResponse
    case networkError(Error)
    case timeout
    
    static func == (lhs: PreferencesError, rhs: PreferencesError) -> Bool {
        switch (lhs, rhs) {
        case (.noAuthStore, .noAuthStore):
            return true
        case (.invalidResponse, .invalidResponse):
            return true
        case (.timeout, .timeout):
            return true
        case (.networkError, .networkError):
            return true // Simplified comparison for Error types
        default:
            return false
        }
    }
}

// MARK: - Onboarding Content
struct OnboardingContent: View {
    let page: Int
    let auth: AuthBridge
    @Binding var userPreferences: UserPreferences
    let suggestedArchetype: ArchetypeSuggestion?
    let onPreferencesSubmit: () async -> Void
    let onboardingStartTime: Date
    @State private var textOpacity = 0.0
    
    private func getPageName() -> String {
        switch page {
        case 0: return "welcome"
        case 1: return "sleep_patterns"
        case 2: return "dream_patterns"
        case 3: return "goals_interests"
        case 4: return "notifications"
        case 5: return "archetype_reveal"
        case 6: return "complete"
        default: return "unknown"
        }
    }
    
    private func getPageEvent() -> AnalyticsEvent {
        switch page {
        case 0: return .onboardingPage1Welcome
        case 1: return .onboardingPage2SleepPatterns
        case 2: return .onboardingPage3DreamPatterns
        case 3: return .onboardingPage4Goals
        case 4: return .onboardingPage5Notifications
        case 5: return .onboardingPage6Archetype
        case 6: return .onboardingPage7Complete
        default: return .onboardingPageViewed
        }
    }
    
    var body: some View {
        VStack(spacing: 32) {
            switch page {
            case 0:
                OnboardingScreen1()
            case 1:
                SleepPatternsScreen(preferences: $userPreferences)
            case 2:
                DreamPatternsScreen(preferences: $userPreferences)
            case 3:
                GoalsInterestsScreen(preferences: $userPreferences)
            case 4:
                NotificationScreen(preferences: $userPreferences)
            case 5:
                if let archetype = suggestedArchetype {
                    ArchetypeRevealScreen(archetype: archetype)
                } else {
                    ArchetypeLoadingScreen()
                }
            case 6:
                OnboardingCompleteScreen(
                    auth: auth,
                    preferences: userPreferences,
                    archetype: suggestedArchetype,
                    onboardingStartTime: onboardingStartTime
                )
            default:
                EmptyView()
            }
        }
        .opacity(textOpacity)
        .onAppear {
            withAnimation(.easeIn(duration: 1.2)) {
                textOpacity = 1.0
            }
            // Track specific page view
            AnalyticsService.shared.track(getPageEvent(), properties: [
                "page_number": page + 1,
                "page_name": getPageName()
            ])
        }
        .onChange(of: page) { _ in
            textOpacity = 0.0
            withAnimation(.easeIn(duration: 1.2).delay(0.2)) {
                textOpacity = 1.0
            }
            // Track specific page view
            AnalyticsService.shared.track(getPageEvent(), properties: [
                "page_number": page + 1,
                "page_name": getPageName()
            ])
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
                .foregroundStyle(DesignSystem.Gradients.dreamGradient)
            
            VStack(spacing: 16) {
                Text("Dreams hold latent magic")
                    .font(DesignSystem.Typography.title1())
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text("Every night, your mind weaves stories only you can tell—filled with hidden wisdom, memories, and pieces of yourself waiting to be discovered.")
                    .font(DesignSystem.Typography.body())
                    .foregroundColor(DesignSystem.Colors.textSecondary)
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
                .foregroundStyle(DesignSystem.Gradients.dreamGradient)
            
            VStack(spacing: 16) {
                Text("Your brain dreams for 2 hours every night")
                    .font(DesignSystem.Typography.title2())
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text("Studies show people who record their dreams report 23% better self-awareness and emotional processing.")
                    .font(DesignSystem.Typography.subheadline())
                    .foregroundStyle(DesignSystem.Gradients.dreamGradient)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                
                Text("Dreams help consolidate memories and work through emotions while you sleep.")
                    .font(DesignSystem.Typography.bodySmall())
                    .foregroundColor(DesignSystem.Colors.textTertiary)
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
                .foregroundStyle(DesignSystem.Gradients.dreamGradient)
            
            VStack(spacing: 16) {
                Text("Dreams are stories only your brain can tell")
                    .font(DesignSystem.Typography.title2())
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text("82% of couples who share dreams report feeling more emotionally connected.")
                    .font(DesignSystem.Typography.subheadline())
                    .foregroundStyle(DesignSystem.Gradients.dreamGradient)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                
                Text("For centuries, humans have gathered around fires to share the visions of sleep—intimate glimpses into our inner worlds.")
                    .font(DesignSystem.Typography.bodySmall())
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
    }
}

// MARK: - New Data Collection Screens

struct SleepPatternsScreen: View {
    @Binding var preferences: UserPreferences
    @State private var selectedBedtime = "22:00"
    @State private var selectedWakeTime = "07:00"
    @State private var selectedSleepQuality = "good"
    
    private let bedtimeOptions = ["21:00", "21:30", "22:00", "22:30", "23:00", "23:30", "00:00", "00:30", "01:00"]
    private let waketimeOptions = ["05:30", "06:00", "06:30", "07:00", "07:30", "08:00", "08:30", "09:00", "09:30"]
    private let sleepQualityOptions = [
        ("poor", "😴 Poor", "I often wake up tired"),
        ("fair", "😐 Fair", "Sometimes good, sometimes not"),
        ("good", "😊 Good", "Usually well-rested"),
        ("excellent", "🌟 Excellent", "I wake up refreshed")
    ]
    
    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 64))
                .foregroundStyle(DesignSystem.Gradients.dreamGradient)
            
            VStack(spacing: 24) {
                Text("Tell us about your sleep")
                    .font(DesignSystem.Typography.title2())
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 20) {
                    // Bedtime picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Typical bedtime")
                            .font(DesignSystem.Typography.subheadline())
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(bedtimeOptions, id: \.self) { time in
                                    Button(time) {
                                        selectedBedtime = time
                                        updatePreferences()
                                        AnalyticsService.shared.track(.onboardingPreferenceSelected, properties: [
                                            "preference_type": "bedtime",
                                            "value": time,
                                            "page": "sleep_patterns"
                                        ])
                                    }
                                    .foregroundColor(selectedBedtime == time ? DesignSystem.Colors.backgroundPrimary : DesignSystem.Colors.textSecondary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(selectedBedtime == time ? AnyShapeStyle(DesignSystem.Gradients.dreamGradient) : AnyShapeStyle(DesignSystem.Colors.cardBackground))
                                    )
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .allowsHitTesting(true)
                    }
                    
                    // Wake time picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Typical wake time")
                            .font(DesignSystem.Typography.subheadline())
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(waketimeOptions, id: \.self) { time in
                                    Button(time) {
                                        selectedWakeTime = time
                                        updatePreferences()
                                        AnalyticsService.shared.track(.onboardingPreferenceSelected, properties: [
                                            "preference_type": "wake_time",
                                            "value": time,
                                            "page": "sleep_patterns"
                                        ])
                                    }
                                    .foregroundColor(selectedWakeTime == time ? DesignSystem.Colors.backgroundPrimary : DesignSystem.Colors.textSecondary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(selectedWakeTime == time ? AnyShapeStyle(DesignSystem.Gradients.dreamGradient) : AnyShapeStyle(DesignSystem.Colors.cardBackground))
                                    )
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .allowsHitTesting(true)
                    }
                    
                    // Sleep quality
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How's your sleep quality?")
                            .font(DesignSystem.Typography.subheadline())
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        VStack(spacing: 8) {
                            ForEach(sleepQualityOptions, id: \.0) { quality in
                                Button {
                                    selectedSleepQuality = quality.0
                                    updatePreferences()
                                    AnalyticsService.shared.track(.onboardingPreferenceSelected, properties: [
                                        "preference_type": "sleep_quality",
                                        "value": quality.0,
                                        "label": quality.1,
                                        "page": "sleep_patterns"
                                    ])
                                } label: {
                                    HStack {
                                        Text(quality.1)
                                            .font(DesignSystem.Typography.subheadline())
                                        
                                        Spacer()
                                        
                                        Text(quality.2)
                                            .font(DesignSystem.Typography.caption())
                                            .foregroundColor(DesignSystem.Colors.textTertiary)
                                        
                                        if selectedSleepQuality == quality.0 {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(DesignSystem.Colors.ember)
                                        }
                                    }
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(selectedSleepQuality == quality.0 ? DesignSystem.Colors.ember.opacity(0.2) : DesignSystem.Colors.ember.opacity(0.1))
                                            .stroke(selectedSleepQuality == quality.0 ? DesignSystem.Colors.ember : DesignSystem.Colors.textPrimary.opacity(0.1), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            // Initialize state from current preferences
            if let bedtime = preferences.typicalBedtime, bedtime.count >= 5 {
                selectedBedtime = String(bedtime.prefix(5)) // Extract HH:MM from HH:MM:SS
            }
            if let wakeTime = preferences.typicalWakeTime, wakeTime.count >= 5 {
                selectedWakeTime = String(wakeTime.prefix(5)) // Extract HH:MM from HH:MM:SS  
            }
            if let quality = preferences.sleepQuality {
                selectedSleepQuality = quality
            }
            updatePreferences()
        }
    }
    
    private func updatePreferences() {
        preferences = UserPreferences(
            id: preferences.id,
            userId: preferences.userId,
            typicalBedtime: selectedBedtime + ":00",
            typicalWakeTime: selectedWakeTime + ":00",
            sleepQuality: selectedSleepQuality,
            dreamRecallFrequency: preferences.dreamRecallFrequency,
            dreamVividness: preferences.dreamVividness,
            commonDreamThemes: preferences.commonDreamThemes,
            primaryGoal: preferences.primaryGoal,
            interests: preferences.interests,
            reminderEnabled: preferences.reminderEnabled,
            reminderTime: preferences.reminderTime,
            reminderFrequency: preferences.reminderFrequency,
            reminderDays: preferences.reminderDays,
            initialArchetype: preferences.initialArchetype,
            personalityTraits: preferences.personalityTraits,
            onboardingCompleted: false
        )
    }
}

struct DreamPatternsScreen: View {
    @Binding var preferences: UserPreferences
    @State private var selectedRecallFrequency = "sometimes"
    @State private var selectedVividness = "moderate"
    @State private var selectedThemes: Set<String> = []
    
    private let recallFrequencyOptions = [
        ("never", "Never", "I don't remember my dreams"),
        ("rarely", "Rarely", "Once in a while"),
        ("sometimes", "Sometimes", "A few times a week"),
        ("often", "Often", "Most nights"),
        ("always", "Always", "Every night")
    ]
    
    private let vividnessOptions = [
        ("vague", "Vague", "Hazy impressions"),
        ("moderate", "Moderate", "Some clear details"),
        ("vivid", "Vivid", "Very detailed"),
        ("very_vivid", "Extremely vivid", "Like real life")
    ]
    
    private let dreamThemes = [
        "flying", "falling", "being_chased", "water", "animals", "family", 
        "work", "school", "death", "food", "vehicles", "buildings",
        "nature", "supernatural", "adventure", "romance"
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 64))
                    .foregroundColor(DesignSystem.Colors.ember)
                
                VStack(spacing: 24) {
                    Text("Your dream patterns")
                        .font(DesignSystem.Typography.title2())
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    VStack(spacing: 20) {
                        // Dream recall frequency
                        VStack(alignment: .leading, spacing: 12) {
                            Text("How often do you remember your dreams?")
                                .font(DesignSystem.Typography.subheadline())
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            VStack(spacing: 8) {
                                ForEach(recallFrequencyOptions, id: \.0) { option in
                                    Button {
                                        selectedRecallFrequency = option.0
                                        updatePreferences()
                                    } label: {
                                        HStack {
                                            Text(option.1)
                                                .font(DesignSystem.Typography.subheadline())
                                            
                                            Spacer()
                                            
                                            Text(option.2)
                                                .font(DesignSystem.Typography.caption())
                                                .foregroundColor(DesignSystem.Colors.textTertiary)
                                            
                                            if selectedRecallFrequency == option.0 {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(DesignSystem.Colors.ember)
                                            }
                                        }
                                        .foregroundColor(DesignSystem.Colors.textPrimary)
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(selectedRecallFrequency == option.0 ? DesignSystem.Colors.ember.opacity(0.2) : DesignSystem.Colors.ember.opacity(0.1))
                                                .stroke(selectedRecallFrequency == option.0 ? DesignSystem.Colors.ember : Color.clear, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        // Dream vividness
                        VStack(alignment: .leading, spacing: 12) {
                            Text("How vivid are your dreams?")
                                .font(DesignSystem.Typography.subheadline())
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            VStack(spacing: 8) {
                                ForEach(vividnessOptions, id: \.0) { option in
                                    Button {
                                        selectedVividness = option.0
                                        updatePreferences()
                                    } label: {
                                        HStack {
                                            Text(option.1)
                                                .font(DesignSystem.Typography.subheadline())
                                            
                                            Spacer()
                                            
                                            Text(option.2)
                                                .font(DesignSystem.Typography.caption())
                                                .foregroundColor(DesignSystem.Colors.textTertiary)
                                            
                                            if selectedVividness == option.0 {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(DesignSystem.Colors.ember)
                                            }
                                        }
                                        .foregroundColor(DesignSystem.Colors.textPrimary)
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(selectedVividness == option.0 ? DesignSystem.Colors.ember.opacity(0.2) : DesignSystem.Colors.ember.opacity(0.1))
                                                .stroke(selectedVividness == option.0 ? DesignSystem.Colors.ember : Color.clear, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        // Common dream themes
                        VStack(alignment: .leading, spacing: 12) {
                            Text("What themes appear in your dreams? (Select any that apply)")
                                .font(DesignSystem.Typography.subheadline())
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            LazyVGrid(columns: [
                                GridItem(.adaptive(minimum: 100))
                            ], spacing: 8) {
                                ForEach(dreamThemes, id: \.self) { theme in
                                    Button {
                                        if selectedThemes.contains(theme) {
                                            selectedThemes.remove(theme)
                                        } else {
                                            selectedThemes.insert(theme)
                                        }
                                        updatePreferences()
                                    } label: {
                                        Text(theme.replacingOccurrences(of: "_", with: " ").capitalized)
                                            .font(DesignSystem.Typography.caption())
                                            .foregroundColor(selectedThemes.contains(theme) ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textTertiary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .fill(selectedThemes.contains(theme) ? DesignSystem.Colors.ember : DesignSystem.Colors.ember.opacity(0.2))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
        }
        .allowsHitTesting(true)
        .onAppear {
            // Initialize state from current preferences
            if let recallFreq = preferences.dreamRecallFrequency {
                selectedRecallFrequency = recallFreq
            }
            if let vividness = preferences.dreamVividness {
                selectedVividness = vividness
            }
            selectedThemes = Set(preferences.commonDreamThemes)
            updatePreferences()
        }
    }
    
    private func updatePreferences() {
        preferences = UserPreferences(
            id: preferences.id,
            userId: preferences.userId,
            typicalBedtime: preferences.typicalBedtime,
            typicalWakeTime: preferences.typicalWakeTime,
            sleepQuality: preferences.sleepQuality,
            dreamRecallFrequency: selectedRecallFrequency,
            dreamVividness: selectedVividness,
            commonDreamThemes: Array(selectedThemes),
            primaryGoal: preferences.primaryGoal,
            interests: preferences.interests,
            reminderEnabled: preferences.reminderEnabled,
            reminderTime: preferences.reminderTime,
            reminderFrequency: preferences.reminderFrequency,
            reminderDays: preferences.reminderDays,
            initialArchetype: preferences.initialArchetype,
            personalityTraits: preferences.personalityTraits,
            onboardingCompleted: false
        )
    }
}

struct GoalsInterestsScreen: View {
    @Binding var preferences: UserPreferences
    @State private var selectedGoal = "self_discovery"
    @State private var selectedInterests: Set<String> = []
    
    private let goalOptions = [
        ("self_discovery", "🔍 Self Discovery", "Understand myself better"),
        ("creativity", "🎨 Creativity", "Boost creative inspiration"),
        ("problem_solving", "🧩 Problem Solving", "Find solutions through dreams"),
        ("emotional_healing", "💚 Emotional Healing", "Process emotions and trauma"),
        ("lucid_dreaming", "✨ Lucid Dreaming", "Control and direct my dreams")
    ]
    
    private let interestOptions = [
        "lucid_dreaming", "symbolism", "emotional_processing", 
        "creativity", "problem_solving", "spiritual_growth",
        "memory_enhancement", "nightmare_resolution", "prophetic_dreams"
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Image(systemName: "target")
                    .font(.system(size: 64))
                    .foregroundColor(DesignSystem.Colors.ember)
                
                VStack(spacing: 24) {
                    Text("What brings you here?")
                        .font(DesignSystem.Typography.title2())
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    VStack(spacing: 20) {
                        // Primary goal
                        VStack(alignment: .leading, spacing: 12) {
                            Text("What's your main goal with dream exploration?")
                                .font(DesignSystem.Typography.subheadline())
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            VStack(spacing: 8) {
                                ForEach(goalOptions, id: \.0) { goal in
                                    Button {
                                        selectedGoal = goal.0
                                        updatePreferences()
                                    } label: {
                                        HStack {
                                            Text(goal.1)
                                                .font(DesignSystem.Typography.subheadline())
                                            
                                            Spacer()
                                            
                                            Text(goal.2)
                                                .font(DesignSystem.Typography.caption())
                                                .foregroundColor(DesignSystem.Colors.textTertiary)
                                            
                                            if selectedGoal == goal.0 {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(DesignSystem.Colors.ember)
                                            }
                                        }
                                        .foregroundColor(DesignSystem.Colors.textPrimary)
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(selectedGoal == goal.0 ? DesignSystem.Colors.ember.opacity(0.2) : DesignSystem.Colors.ember.opacity(0.1))
                                                .stroke(selectedGoal == goal.0 ? DesignSystem.Colors.ember : Color.clear, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        // Interests
                        VStack(alignment: .leading, spacing: 12) {
                            Text("What interests you most? (Select any that apply)")
                                .font(DesignSystem.Typography.subheadline())
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            LazyVGrid(columns: [
                                GridItem(.adaptive(minimum: 120))
                            ], spacing: 8) {
                                ForEach(interestOptions, id: \.self) { interest in
                                    Button {
                                        if selectedInterests.contains(interest) {
                                            selectedInterests.remove(interest)
                                        } else {
                                            selectedInterests.insert(interest)
                                        }
                                        updatePreferences()
                                    } label: {
                                        Text(interest.replacingOccurrences(of: "_", with: " ").capitalized)
                                            .font(DesignSystem.Typography.caption())
                                            .foregroundColor(selectedInterests.contains(interest) ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textTertiary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .fill(selectedInterests.contains(interest) ? DesignSystem.Colors.ember : DesignSystem.Colors.ember.opacity(0.2))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
        }
        .allowsHitTesting(true)
        .onAppear {
            // Initialize state from current preferences
            if let goal = preferences.primaryGoal {
                selectedGoal = goal
            }
            selectedInterests = Set(preferences.interests)
            updatePreferences()
        }
    }
    
    private func updatePreferences() {
        preferences = UserPreferences(
            id: preferences.id,
            userId: preferences.userId,
            typicalBedtime: preferences.typicalBedtime,
            typicalWakeTime: preferences.typicalWakeTime,
            sleepQuality: preferences.sleepQuality,
            dreamRecallFrequency: preferences.dreamRecallFrequency,
            dreamVividness: preferences.dreamVividness,
            commonDreamThemes: preferences.commonDreamThemes,
            primaryGoal: selectedGoal,
            interests: Array(selectedInterests),
            reminderEnabled: preferences.reminderEnabled,
            reminderTime: preferences.reminderTime,
            reminderFrequency: preferences.reminderFrequency,
            reminderDays: preferences.reminderDays,
            initialArchetype: preferences.initialArchetype,
            personalityTraits: preferences.personalityTraits,
            onboardingCompleted: false
        )
    }
}

struct NotificationScreen: View {
    @Binding var preferences: UserPreferences
    @State private var reminderEnabled = false  // Default to OFF so user must actively enable
    @State private var selectedTime = "08:00"
    @State private var selectedFrequency = "daily"
    
    private let timeOptions = ["07:00", "07:30", "08:00", "08:30", "09:00", "09:30", "10:00"]
    private let frequencyOptions = [
        ("daily", "Daily", "Every morning"),
        ("weekly", "Weekly", "Once a week"),
        ("custom", "Custom", "Specific days")
    ]
    
    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "bell.badge")
                .font(.system(size: 64))
                .foregroundColor(DesignSystem.Colors.ember)
            
            VStack(spacing: 24) {
                Text("Dream capture reminders")
                    .font(DesignSystem.Typography.title2())
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text("We can gently remind you to record your dreams when they're freshest in your memory.")
                    .font(DesignSystem.Typography.body())
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                
                VStack(spacing: 20) {
                    // Enable/disable toggle
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Enable reminders")
                                .font(DesignSystem.Typography.subheadline())
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            Text("Get gentle nudges to capture your dreams")
                                .font(DesignSystem.Typography.caption())
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $reminderEnabled)
                            .toggleStyle(SwitchToggleStyle(tint: DesignSystem.Colors.ember))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(DesignSystem.Colors.ember.opacity(0.1))
                    )
                    
                    if reminderEnabled {
                        // Time picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reminder time")
                                .font(DesignSystem.Typography.subheadline())
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(timeOptions, id: \.self) { time in
                                        Button(time) {
                                            selectedTime = time
                                            updatePreferences()
                                        }
                                        .foregroundColor(selectedTime == time ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textTertiary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 20)
                                                .fill(selectedTime == time ? DesignSystem.Colors.ember : DesignSystem.Colors.ember.opacity(0.2))
                                        )
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                            .allowsHitTesting(true)
                        }
                        
                        // Frequency picker
                        VStack(alignment: .leading, spacing: 12) {
                            Text("How often?")
                                .font(DesignSystem.Typography.subheadline())
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            VStack(spacing: 8) {
                                ForEach(frequencyOptions, id: \.0) { freq in
                                    Button {
                                        selectedFrequency = freq.0
                                        updatePreferences()
                                    } label: {
                                        HStack {
                                            Text(freq.1)
                                                .font(DesignSystem.Typography.subheadline())
                                            
                                            Spacer()
                                            
                                            Text(freq.2)
                                                .font(DesignSystem.Typography.caption())
                                                .foregroundColor(DesignSystem.Colors.textTertiary)
                                            
                                            if selectedFrequency == freq.0 {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(DesignSystem.Colors.ember)
                                            }
                                        }
                                        .foregroundColor(DesignSystem.Colors.textPrimary)
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(selectedFrequency == freq.0 ? DesignSystem.Colors.ember.opacity(0.2) : DesignSystem.Colors.ember.opacity(0.1))
                                                .stroke(selectedFrequency == freq.0 ? DesignSystem.Colors.ember : Color.clear, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            // Initialize time and frequency from preferences, but NOT the enabled state
            // This ensures users must actively toggle ON to trigger permission request
            if let reminderTime = preferences.reminderTime, reminderTime.count >= 5 {
                selectedTime = String(reminderTime.prefix(5)) // Extract HH:MM from HH:MM:SS
            }
            selectedFrequency = preferences.reminderFrequency
            
            // Don't auto-enable based on preferences during onboarding
            #if DEBUG
            print("🔔 [NOTIFICATION] NotificationScreen appeared, toggle is: \(reminderEnabled ? "ON" : "OFF")")
            #endif
            updatePreferences()
        }
        .onChange(of: reminderEnabled) { oldValue, newValue in
            #if DEBUG
            print("🔔 [NOTIFICATION] Toggle changed from \(oldValue) to \(newValue)")
            #endif
            // Just update preferences - we'll request permission when completing onboarding
            updatePreferences()
        }
    }
    
    private func updatePreferences() {
        preferences = UserPreferences(
            id: preferences.id,
            userId: preferences.userId,
            typicalBedtime: preferences.typicalBedtime,
            typicalWakeTime: preferences.typicalWakeTime,
            sleepQuality: preferences.sleepQuality,
            dreamRecallFrequency: preferences.dreamRecallFrequency,
            dreamVividness: preferences.dreamVividness,
            commonDreamThemes: preferences.commonDreamThemes,
            primaryGoal: preferences.primaryGoal,
            interests: preferences.interests,
            reminderEnabled: reminderEnabled,
            reminderTime: reminderEnabled ? selectedTime + ":00" : nil,
            reminderFrequency: selectedFrequency,
            reminderDays: [],
            initialArchetype: preferences.initialArchetype,
            personalityTraits: preferences.personalityTraits,
            onboardingCompleted: false
        )
    }
}

struct ArchetypeLoadingScreen: View {
    var body: some View {
        VStack(spacing: 32) {
            // Animated loading indicator
            Image(systemName: "sparkles")
                .font(.system(size: 64))
                .foregroundColor(DesignSystem.Colors.ember)
                .scaleEffect(1.2)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: true)
            
            VStack(spacing: 16) {
                Text("Analyzing your dream essence...")
                    .font(DesignSystem.Typography.title2())
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text("We're discovering your unique dream archetype based on your preferences. This will help us personalize your experience.")
                    .font(DesignSystem.Typography.body())
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.ember))
                .scaleEffect(1.2)
        }
    }
}

struct ArchetypeRevealScreen: View {
    let archetype: ArchetypeSuggestion
    @State private var showDetails = false
    
    var body: some View {
        VStack(spacing: 32) {
            // Archetype symbol with glow effect
            Text(archetype.archetypeDetails.symbol)
                .font(.system(size: 80))
                .scaleEffect(showDetails ? 1.2 : 1.0)
                .shadow(color: DesignSystem.Colors.ember.opacity(0.8), radius: showDetails ? 20 : 10)
                .animation(.easeInOut(duration: 2.0), value: showDetails)
            
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("You are a")
                        .font(DesignSystem.Typography.subheadline())
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .opacity(showDetails ? 1 : 0)
                    
                    Text(archetype.archetypeDetails.name)
                        .font(DesignSystem.Typography.largeTitle())
                        .foregroundColor(DesignSystem.Colors.ember)
                        .multilineTextAlignment(.center)
                        .opacity(showDetails ? 1 : 0)
                }
                
                VStack(spacing: 16) {
                    Text(archetype.archetypeDetails.description)
                        .font(DesignSystem.Typography.body())
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .opacity(showDetails ? 1 : 0)
                    
                    // Confidence indicator
                    HStack {
                        Text("Confidence:")
                            .font(DesignSystem.Typography.caption())
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                        
                        Text("\(Int(archetype.confidence * 100))%")
                            .font(DesignSystem.Typography.caption())
                            .foregroundColor(DesignSystem.Colors.ember)
                    }
                    .opacity(showDetails ? 1 : 0)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).delay(0.5)) {
                showDetails = true
            }
            
            // Track archetype reveal
            AnalyticsService.shared.track(.archetypeRevealed, properties: [
                "archetype": archetype.suggestedArchetype,
                "confidence": archetype.confidence,
                "archetype_name": archetype.archetypeDetails.name
            ])
        }
    }
}

struct OnboardingCompleteScreen: View {
    let auth: AuthBridge
    let preferences: UserPreferences
    let archetype: ArchetypeSuggestion?
    let onboardingStartTime: Date
    
    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(DesignSystem.Colors.ember)
            
            VStack(spacing: 16) {
                Text("Welcome to your dream journey!")
                    .font(DesignSystem.Typography.title2())
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text("Your profile is now personalized. Start recording your dreams to unlock deeper insights and discover patterns unique to you.")
                    .font(DesignSystem.Typography.body())
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            Button("Begin Dream Capture") {
                // Track onboarding completion
                AnalyticsService.shared.trackDuration(
                    event: .onboardingCompleted,
                    startTime: onboardingStartTime,
                    properties: [
                        "archetype": archetype?.suggestedArchetype ?? "unknown",
                        "archetype_confidence": archetype?.confidence ?? 0,
                        "notifications_enabled": preferences.reminderEnabled,
                        "primary_goal": preferences.primaryGoal ?? "unknown"
                    ]
                )
                
                Task {
                    // First request notification permission if reminders are enabled
                    if preferences.reminderEnabled {
                        #if DEBUG
                        print("🔔 [COMPLETION] Requesting notification permission...")
                        #endif
                        
                        do {
                            let center = UNUserNotificationCenter.current()
                            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                            
                            if granted {
                                #if DEBUG
                                print("✅ [COMPLETION] Permission granted, scheduling notifications...")
                                #endif
                                
                                // Now schedule notifications
                                if let reminderTime = preferences.reminderTime {
                                    let scheduler = NotificationScheduler.shared
                                    let timeString = String(reminderTime.prefix(5))
                                    
                                    try await scheduler.scheduleReminders(
                                        time: timeString,
                                        frequency: preferences.reminderFrequency,
                                        archetype: archetype?.suggestedArchetype
                                    )
                                    #if DEBUG
                                    print("✅ Scheduled \(preferences.reminderFrequency) reminders at \(timeString)")
                                    
                                    // Schedule a preview notification for 10 seconds from now
                                    try await scheduler.scheduleTestNotification(
                                        archetype: archetype?.suggestedArchetype
                                    )
                                    print("\n🔔 NOTIFICATION PREVIEW:")
                                    print("   A preview of your daily reminder will appear in 10 seconds")
                                    print("   This is exactly how your 8:00 AM reminder will look")
                                    print("   📱 Press Cmd+Shift+H (home button) now to see it!\n")
                                    
                                    // Also print what notifications are scheduled
                                    await scheduler.printScheduledNotifications()
                                    #endif
                                }
                            } else {
                                #if DEBUG
                                print("❌ [COMPLETION] Permission denied")
                                #endif
                            }
                        } catch {
                            #if DEBUG
                            print("⚠️ [COMPLETION] Failed to request permission or schedule: \(error)")
                            #endif
                        }
                    }
                    
                    // Complete onboarding regardless of notification status
                    auth.completeOnboarding()
                }
            }
            .font(DesignSystem.Typography.subheadline())
            .foregroundColor(DesignSystem.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 27)
                    .fill(DesignSystem.Gradients.dreamGradient)
            )
            .padding(.horizontal, 24)
            .padding(.top, 16)
        }
    }
}

