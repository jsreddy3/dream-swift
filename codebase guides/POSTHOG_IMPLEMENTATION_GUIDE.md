# PostHog Analytics Implementation Guide

## Overview
This guide shows exactly where to add analytics tracking in the Dream app using PostHog.

## Setup Checklist

- [ ] Create PostHog account at app.posthog.com
- [ ] Get API keys (test and production)
- [ ] Update API keys in dreamApp.swift
- [ ] Run `swift package update` to fetch PostHog SDK
- [ ] Test in simulator first

## Key Analytics Points to Implement

### 1. App Launch (dreamApp.swift)
```swift
// In .onAppear of RootView
.onAppear {
    AnalyticsService.shared.track(.appLaunched, properties: [
        "has_jwt": auth.jwt != nil,
        "launch_type": auth.jwt != nil ? "returning" : "new"
    ])
}
```

### 2. Authentication Flow (RootView.swift)

#### Sign In Started
```swift
// In GoogleSignInButton action
Button {
    AnalyticsService.shared.track(.signInStarted)
    // ... existing code
}
```

#### Sign In Completed
```swift
// In AuthBridge.signIn() after success
try await backend.signIn(from: vc)
await MainActor.run { 
    jwt = backend.jwt
    AnalyticsService.shared.identify(userId: extractUserIdFromJWT(jwt))
    AnalyticsService.shared.track(.signInCompleted)
}
```

#### Sign Out
```swift
// In AuthBridge.signOut()
func signOut() {
    AnalyticsService.shared.track(.signOutCompleted)
    AnalyticsService.shared.reset()  // Clear user identity
    // ... existing code
}
```

### 3. Onboarding Flow (OnboardingPlaceholderView)

#### Track Page Views
```swift
// In OnboardingContent.onAppear
.onAppear {
    let pageName = getPageName(for: page)
    AnalyticsService.shared.trackOnboardingPage(page + 1, pageName: pageName)
}

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
```

#### Track Onboarding Start
```swift
// Add to OnboardingPlaceholderView
@State private var onboardingStartTime = Date()

var body: some View {
    ZStack {
        // ... existing code
    }
    .onAppear {
        if !hasTrackedStart {
            AnalyticsService.shared.track(.onboardingStarted)
            hasTrackedStart = true
        }
    }
}
```

#### Track Skip
```swift
Button("Skip") {
    AnalyticsService.shared.track(.onboardingSkipped, properties: [
        "skipped_at_page": currentPage + 1
    ])
    auth.completeOnboarding()
}
```

#### Track Completion
```swift
// In OnboardingCompleteScreen button
Button("Begin Dream Capture") {
    AnalyticsService.shared.trackDuration(
        event: .onboardingCompleted,
        startTime: onboardingStartTime,
        properties: [
            "archetype": archetype?.suggestedArchetype ?? "unknown",
            "notifications_enabled": preferences.reminderEnabled
        ]
    )
    // ... existing code
}
```

### 4. Dream Recording Flow (ContentView.swift)

#### Recording Started
```swift
// In CaptureViewModel.startOrStop()
func startOrStop() {
    if state == .idle {
        AnalyticsService.shared.track(.dreamRecordingStarted, properties: [
            "mode": "voice"
        ])
    }
    // ... existing code
}
```

#### Recording Completed
```swift
// When user taps "Complete Dream"
Button {
    AnalyticsService.shared.track(.dreamRecordingCompleted, properties: [
        "segments_count": vm.segmentsCount,
        "extended": vm.wasExtended
    ])
    vm.finish()
}
```

#### Dream Saved
```swift
// In onChange(of: vm.lastSavedDream)
.onChange(of: vm.lastSavedDream) { dream in
    guard let dream else { return }
    AnalyticsService.shared.track(.dreamSaved, properties: [
        "dream_id": dream.id,
        "duration_seconds": dream.durationSeconds
    ])
}
```

### 5. Notification Permission
```swift
// In OnboardingCompleteScreen
let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
AnalyticsService.shared.track(
    granted ? .notificationPermissionGranted : .notificationPermissionDenied
)
```

## PostHog Dashboard Setup

### 1. Create Key Funnels

**Onboarding Funnel:**
1. onboarding_started
2. onboarding_page_viewed (page: 1)
3. onboarding_page_viewed (page: 4)
4. onboarding_completed

**Dream Recording Funnel:**
1. dream_recording_started
2. dream_recording_completed
3. dream_saved

### 2. Key Metrics to Track

- **Onboarding Completion Rate**: onboarding_completed / onboarding_started
- **Skip Rate**: onboarding_skipped / onboarding_started
- **Average Onboarding Duration**: duration_seconds on onboarding_completed
- **Dream Recording Success Rate**: dream_saved / dream_recording_started
- **Notification Opt-in Rate**: notification_permission_granted / onboarding_completed

### 3. User Properties to Set

```swift
// After preferences are saved
AnalyticsService.shared.identify(userId, properties: [
    "archetype": archetype,
    "primary_goal": preferences.primaryGoal,
    "sleep_quality": preferences.sleepQuality,
    "dream_recall_frequency": preferences.dreamRecallFrequency,
    "notifications_enabled": preferences.reminderEnabled
])
```

## Testing Strategy

### Phase 1: Debug Mode Only
1. Keep analytics in debug mode initially
2. Verify events appear in PostHog dashboard
3. Check that all properties are captured correctly

### Phase 2: Test Flight
1. Enable for beta testers
2. Monitor for any crashes or performance issues
3. Verify data quality

### Phase 3: Production
1. Enable for all users
2. Set up alerts for anomalies
3. Create weekly reports

## Privacy Considerations

1. **No PII**: Don't track names, emails, or other personal info
2. **User Control**: Add analytics opt-out in settings
3. **Transparency**: Update privacy policy

## Implementation Order (Safe Approach)

1. **Week 1**: Add package and basic setup
2. **Week 2**: Track app launch and auth events only
3. **Week 3**: Add onboarding tracking
4. **Week 4**: Add dream recording tracking
5. **Week 5**: Review data and optimize

## Rollback Plan

If issues arise, disable analytics by changing one line:
```swift
private let enabledInDebug: Bool = false  // Disables all tracking
```

Or remove initialization:
```swift
// Comment out in dreamApp.swift
// AnalyticsService.shared.configure(apiKey: "...")
```

## Common Issues & Solutions

**Issue**: Build fails after adding PostHog
- **Solution**: Run `swift package resolve` and clean build

**Issue**: No events appearing in dashboard
- **Solution**: Check API key and ensure device has internet

**Issue**: App performance degraded
- **Solution**: PostHog batches events, but you can adjust batch size in config

## Next Steps After Implementation

1. **Create Dashboards**: Build dashboards for each key metric
2. **Set Up Alerts**: Alert if onboarding completion drops below 70%
3. **Weekly Reviews**: Review funnel performance weekly
4. **Iterate**: Use data to improve weak points in the flow