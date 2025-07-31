# Onboarding Testing Guide

## Overview
The Dream app includes a feature flag system to control onboarding behavior for testing and development. This document explains how the system works and how to use it effectively.

## Feature Flag Location
```swift
// File: Configuration/Sources/Configuration/Configuration.swift
public static let forceOnboardingForTesting: Bool = false  // Toggle this
```

## How It Works

### When `forceOnboardingForTesting = true` (Testing Mode)
- **ALWAYS** shows onboarding for ALL users
- Ignores dream count
- Ignores UserDefaults completion status
- Useful for: UI development, screenshot capture, QA testing

### When `forceOnboardingForTesting = false` (Production Mode)
- Uses normal business logic:
  - New users (0 dreams + not completed) → Show onboarding
  - Users with dreams → Skip onboarding
  - Users who completed onboarding → Skip onboarding

## Onboarding Logic Flow

```swift
// Location: Features/Sources/Features/RootView.swift
private func checkOnboardingNeeded() async {
    let dreams = try await store.allDreams()
    let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    
    // Feature flag override
    let forceOnboarding = Config.forceOnboardingForTesting
    
    // Normal logic: no dreams AND not completed
    let normalLogicShouldShow = dreams.isEmpty && !hasCompletedOnboarding
    
    // Final decision: force OR normal logic
    let shouldShowOnboarding = forceOnboarding || normalLogicShouldShow
}
```

## Testing Scenarios

### Test Matrix

| Scenario | Feature Flag | Dreams | Completed | Expected Result |
|----------|--------------|--------|-----------|-----------------|
| New User | OFF | 0 | false | ✅ Show Onboarding |
| New User | ON | 0 | false | ✅ Show Onboarding |
| Existing User | OFF | >0 | any | ❌ Skip Onboarding |
| Existing User | ON | >0 | any | ✅ Show Onboarding |
| Completed User | OFF | 0 | true | ❌ Skip Onboarding |
| Completed User | ON | 0 | true | ✅ Show Onboarding |

### How to Test Each Scenario

1. **Test Feature Flag Override**
   ```swift
   // Set to true in Configuration.swift
   forceOnboardingForTesting = true
   ```
   - Build & run
   - Sign in with ANY account
   - Should ALWAYS see onboarding

2. **Test New User Flow**
   ```swift
   // Set to false in Configuration.swift
   forceOnboardingForTesting = false
   ```
   - Reset simulator or delete app
   - Sign in with new account
   - Should see onboarding

3. **Test Existing User Flow**
   - Ensure user has dreams recorded
   - Sign in
   - Should skip directly to record screen

## Debug Features

### Console Logs
Watch Xcode console for detailed flow:
```
🔍 [ONBOARDING DEBUG] Starting onboarding check...
🔍 [ONBOARDING DEBUG] Feature flag forceOnboardingForTesting: false
🔍 [ONBOARDING DEBUG] Dreams count: 0
🔍 [ONBOARDING DEBUG] Dreams isEmpty: true
🔍 [ONBOARDING DEBUG] UserDefaults hasCompletedOnboarding: false
🔍 [ONBOARDING DEBUG] Normal logic would show: true
🔍 [ONBOARDING DEBUG] Final decision - Should show onboarding: true
```

### Visual Debug Info
When onboarding is shown, look for debug info in top-left:
- Shows current feature flag state
- Shows current page number
- Yellow text for easy visibility

### Navigation Debug
```
🔍 [TAP DEBUG] Right tap - advancing to next page
🔍 [NAV DEBUG] Advancing from page 0 to 1
```

## Common Use Cases

### 1. UI Development
```swift
forceOnboardingForTesting = true  // Always show onboarding
```
Use when:
- Tweaking onboarding design
- Testing animations
- Taking screenshots

### 2. QA Testing
```swift
forceOnboardingForTesting = true  // Force specific flows
```
Use when:
- Testing onboarding completion
- Verifying skip functionality
- Testing navigation

### 3. Production Testing
```swift
forceOnboardingForTesting = false  // Real user experience
```
Use when:
- Verifying new user experience
- Testing dream detection logic
- Final pre-release testing

## Resetting User State

To fully reset a user for testing:

1. **Clear UserDefaults**
   ```swift
   UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
   ```

2. **Clear Local Dreams**
   - Delete app from simulator
   - Or clear Documents directory

3. **Reset Backend State**
   - Sign in with different account
   - Or clear backend dreams for test user

## Important Notes

1. **Loading State**: The app shows a loading screen while checking onboarding status to prevent UI flashing

2. **Manual Navigation**: Onboarding uses manual tap navigation:
   - Left side: Previous page
   - Right side: Next page
   - No auto-advance timer

3. **Completion**: Onboarding completes when:
   - User taps through all 4 pages
   - User taps "Skip" button
   - Sets `hasCompletedOnboarding = true` in UserDefaults

## Troubleshooting

### "I'm not seeing onboarding when I should"
1. Check feature flag setting
2. Check console logs for decision path
3. Verify UserDefaults state
4. Check dream count from backend

### "Onboarding shows every time"
1. Feature flag might be ON
2. UserDefaults might be corrupted
3. Backend might not be saving dreams

### "Taps aren't working"
1. Check console for tap debug logs
2. Ensure gesture recognizers are set up
3. Check for overlapping UI elements

## Future Improvements

Consider adding:
- Remote feature flag control
- A/B testing support
- Analytics tracking
- Onboarding version tracking