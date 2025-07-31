# Notification Testing Guide

## Quick Test (10 seconds)

Add this temporary code to test notifications immediately after onboarding:

```swift
// In OnboardingCompleteScreen, after scheduling real notifications:
#if DEBUG
// Schedule a test notification for 10 seconds from now
try await scheduler.scheduleTestNotification(
    archetype: archetype?.suggestedArchetype
)
#endif
```

## Full Testing Checklist

### 1. Permission Flow Testing

**Test Case 1.1: First-time Permission Request**
- [ ] Fresh install (delete app first)
- [ ] Go through onboarding
- [ ] On notification screen, toggle ON
- [ ] Verify iOS permission popup appears
- [ ] Tap "Allow"
- [ ] Complete onboarding
- Expected: Permission granted, notifications scheduled

**Test Case 1.2: Permission Denied**
- [ ] Fresh install
- [ ] On notification screen, toggle ON
- [ ] When permission popup appears, tap "Don't Allow"
- [ ] Complete onboarding
- Expected: Onboarding completes successfully, preferences saved

**Test Case 1.3: No Permission Request**
- [ ] Go through onboarding
- [ ] Leave reminder toggle OFF
- [ ] Complete onboarding
- Expected: No permission popup, no notifications scheduled

### 2. Notification Scheduling Testing

**Test Case 2.1: Daily Notifications**
- [ ] Enable reminders
- [ ] Select time (e.g., 08:00)
- [ ] Select "Daily"
- [ ] Complete onboarding
- [ ] Check console logs for "✅ Scheduled daily reminders"

**Test Case 2.2: Different Times**
- [ ] Test with different times (07:00, 09:30, etc.)
- [ ] Verify time is parsed correctly in logs

### 3. Actual Notification Delivery

**Test Case 3.1: Quick Test (Simulator)**
```swift
// Add to AppDelegate.swift temporarily
func applicationDidBecomeActive(_ application: UIApplication) {
    Task {
        let scheduler = NotificationScheduler.shared
        await scheduler.printScheduledNotifications()
    }
}
```

**Test Case 3.2: Real Device Testing**
- [ ] Set notification for 1-2 minutes in the future
- [ ] Close the app completely
- [ ] Wait for notification
- [ ] Verify notification appears with correct:
  - Title: "Dream Capture Time"
  - Body: Personalized message based on archetype
  - Sound plays

### 4. Archetype Personalization

Test each archetype message:
- [ ] Starweaver: "What patterns did the stars weave in your dreams? 🌟"
- [ ] Moonwalker: "Where did your dream journey take you last night? 🌙"
- [ ] Soulkeeper: "What emotions surfaced in your dreams? 💫"
- [ ] Timeseeker: "What memories or visions visited you? ⏳"
- [ ] Shadowmender: "What shadows revealed their secrets? 🌑"
- [ ] Lightbringer: "What light illuminated your dreams? ☀️"
- [ ] Default: "Your dreams are waiting to be remembered 🌙"

### 5. Edge Cases

**Test Case 5.1: Time Zone Changes**
- [ ] Schedule notification
- [ ] Change device time zone
- [ ] Verify notification still fires at local time

**Test Case 5.2: App Deletion/Reinstall**
- [ ] Schedule notifications
- [ ] Delete app
- [ ] Reinstall
- [ ] Verify old notifications are cleared

**Test Case 5.3: Multiple Onboarding Attempts**
- [ ] Use Config.forceOnboardingForTesting
- [ ] Go through onboarding multiple times
- [ ] Verify only one set of notifications scheduled

## Debug Commands

### In LLDB Console:
```
po await NotificationScheduler.shared.printScheduledNotifications()
```

### Check Notification Settings:
```swift
// Add temporarily to any view
.onAppear {
    Task {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        print("Auth Status: \(settings.authorizationStatus.rawValue)")
        print("Alert: \(settings.alertSetting.rawValue)")
        print("Sound: \(settings.soundSetting.rawValue)")
    }
}
```

## Common Issues & Solutions

### Notifications Not Appearing
1. Check device Settings > Dream > Notifications
2. Ensure "Allow Notifications" is ON
3. Check Alert, Sound, and Badge are enabled
4. Make sure device is not in Do Not Disturb

### Permission Popup Not Showing
- Already asked once (check Settings)
- Running on simulator with notifications disabled
- Previous install already set permission

### Wrong Time
- Check time zone settings
- Verify time string format (HH:MM)
- Check 24-hour vs 12-hour format

## Production Verification

Before shipping:
1. Test on real device (not just simulator)
2. Test with app in background
3. Test with device locked
4. Test after device restart
5. Verify notifications work after 24+ hours