import Foundation
import PostHog

/// Centralized analytics service that wraps PostHog
/// This abstraction makes it easy to disable or switch providers
public final class AnalyticsService: @unchecked Sendable {
    public static let shared = AnalyticsService()
    
    private var isEnabled: Bool = false
    private let enabledInDebug: Bool = true  // Set to false to disable in debug builds
    private var posthogInstance: PostHogSDK?
    
    private init() {}
    
    /// Initialize analytics - call this in app launch
    public func configure(apiKey: String, host: String = "https://app.posthog.com") {
        #if DEBUG
        guard enabledInDebug else { 
            print("📊 Analytics disabled in debug mode")
            return 
        }
        #endif
        
        let config = PostHogConfig(apiKey: apiKey, host: host)
        config.captureApplicationLifecycleEvents = false  // We'll track manually
        config.captureScreenViews = false  // More control
        
        #if DEBUG
        // Enable debug logging for PostHog
        config.debug = true
        #endif
        
        posthogInstance = PostHogSDK.with(config)
        isEnabled = true
        
        print("📊 Analytics configured successfully")
        print("📊 PostHog instance created: \(posthogInstance != nil)")
    }
    
    /// Identify user after sign in
    public func identify(userId: String, properties: [String: Any] = [:]) {
        guard isEnabled else { return }
        posthogInstance?.identify(userId, userProperties: properties)
    }
    
    /// Reset user on sign out
    public func reset() {
        guard isEnabled else { return }
        posthogInstance?.reset()
    }
    
    /// Track an event
    public func track(_ event: AnalyticsEvent, properties: [String: Any] = [:]) {
        guard isEnabled else {
            #if DEBUG
            print("📊 [Analytics] Would track: \(event.rawValue) | \(properties)")
            #endif
            return
        }
        
        #if DEBUG
        print("📊 [Analytics] Tracking: \(event.rawValue) | \(properties)")
        #endif
        
        posthogInstance?.capture(event.rawValue, properties: properties)
        
        // Force flush in debug mode for immediate testing
        #if DEBUG
        posthogInstance?.flush()
        #endif
    }
    
    /// Track screen view
    public func screen(_ name: String, properties: [String: Any] = [:]) {
        guard isEnabled else { return }
        posthogInstance?.screen(name)
    }
}

/// All analytics events in one place for consistency
public enum AnalyticsEvent: String {
    // Onboarding - General
    case onboardingStarted = "onboarding_started"
    case onboardingPageViewed = "onboarding_page_viewed"  // Generic fallback
    case onboardingCompleted = "onboarding_completed"
    case onboardingSkipped = "onboarding_skipped"
    case archetypeRevealed = "archetype_revealed"
    
    // Onboarding - Specific Pages
    case onboardingPage1Welcome = "onboarding_page_1_welcome"
    case onboardingPage2SleepPatterns = "onboarding_page_2_sleep_patterns"
    case onboardingPage3DreamPatterns = "onboarding_page_3_dream_patterns"
    case onboardingPage4Goals = "onboarding_page_4_goals"
    case onboardingPage5Notifications = "onboarding_page_5_notifications"
    case onboardingPage6Archetype = "onboarding_page_6_archetype"
    case onboardingPage7Complete = "onboarding_page_7_complete"
    
    // Onboarding - Button Actions
    case onboardingButtonNext = "onboarding_button_next"
    case onboardingButtonPrevious = "onboarding_button_previous"
    case onboardingButtonSkip = "onboarding_button_skip"
    case onboardingPreferenceSelected = "onboarding_preference_selected"
    
    // Authentication
    case signInStarted = "signin_started"
    case signInCompleted = "signin_completed"
    case signInFailed = "signin_failed"
    case signOutCompleted = "signout_completed"
    case tokenRefreshed = "token_refreshed"
    case tokenRefreshFailed = "token_refresh_failed"
    
    // Dream Recording
    case dreamRecordingStarted = "dream_recording_started"
    case dreamRecordingCompleted = "dream_recording_completed"
    case dreamRecordingExtended = "dream_recording_extended"
    case dreamSaved = "dream_saved"
    
    // First Dream Celebration
    case firstDreamCelebrationShown = "first_dream_celebration_shown"
    case firstDreamCelebrationDismissed = "first_dream_celebration_dismissed"
    
    // App Lifecycle
    case appLaunched = "app_launched"
    case appEnteredBackground = "app_entered_background"
    case notificationPermissionGranted = "notification_permission_granted"
    case notificationPermissionDenied = "notification_permission_denied"
}

// Convenience functions
public extension AnalyticsService {
    /// Track onboarding page with automatic page number
    func trackOnboardingPage(_ pageNumber: Int, pageName: String) {
        track(.onboardingPageViewed, properties: [
            "page_number": pageNumber,
            "page_name": pageName,
            "total_pages": 6
        ])
    }
    
    /// Track duration events
    func trackDuration(event: AnalyticsEvent, startTime: Date, properties: [String: Any] = [:]) {
        var props = properties
        props["duration_seconds"] = Int(Date().timeIntervalSince(startTime))
        track(event, properties: props)
    }
}