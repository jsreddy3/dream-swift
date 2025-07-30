//
//  NotificationScheduler+Debug.swift
//  Infrastructure
//
//  Debug helpers for testing notifications
//

#if DEBUG
import Foundation
import UserNotifications

extension NotificationScheduler {
    
    /// Schedules a test notification to fire in 10 seconds
    /// Useful for testing without waiting for the actual scheduled time
    public func scheduleTestNotification(archetype: String? = nil) async throws {
        let center = UNUserNotificationCenter.current()
        
        // Check permission - handle non-sendable type properly
        let authorized = await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus == .authorized)
            }
        }
        
        guard authorized else {
            print("⚠️ DEBUG: No notification permission")
            return
        }
        
        // Create test content that looks like the real notification
        let content = UNMutableNotificationContent()
        content.title = "Dream Capture Time"
        content.sound = .default
        
        // Add personalized message based on archetype
        switch archetype {
        case "starweaver":
            content.body = "What patterns did the stars weave in your dreams? 🌟"
        case "moonwalker":
            content.body = "Where did your dream journey take you last night? 🌙"
        case "soulkeeper":
            content.body = "What emotions surfaced in your dreams? 💫"
        case "timeseeker":
            content.body = "What memories or visions visited you? ⏳"
        case "shadowmender":
            content.body = "What shadows revealed their secrets? 🌑"
        case "lightbringer":
            content.body = "What light illuminated your dreams? ☀️"
        default:
            content.body = "Your dreams are waiting to be remembered 🌙"
        }
        
        // No subtitle for cleaner appearance
        // content.subtitle removed
        
        // Schedule for 10 seconds from now
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: 10,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "dream-test-notification",
            content: content,
            trigger: trigger
        )
        
        try await center.add(request)
        print("✅ DEBUG: Test notification scheduled for 10 seconds from now")
    }
    
    /// Prints all currently scheduled notifications
    public func printScheduledNotifications() async {
        let center = UNUserNotificationCenter.current()
        
        // Handle non-sendable type properly
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            center.getPendingNotificationRequests { requests in
                print("\n📅 Scheduled Notifications:")
                if requests.isEmpty {
                    print("   No notifications scheduled")
                } else {
                    for request in requests {
                        print("   ID: \(request.identifier)")
                        if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                            print("   Time: \(trigger.dateComponents)")
                            print("   Repeats: \(trigger.repeats)")
                        }
                        print("   Title: \(request.content.title)")
                        print("   Body: \(request.content.body)")
                        print("   ---")
                    }
                }
                print("")
                continuation.resume(returning: ())
            }
        }
    }
}
#endif