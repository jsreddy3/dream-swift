//
//  NotificationScheduler.swift
//  Infrastructure
//
//  Handles local notification scheduling for dream capture reminders
//

import Foundation
import UserNotifications

/// Actor responsible for scheduling and managing local notifications
public actor NotificationScheduler {
    
    /// Shared instance for app-wide notification scheduling
    public static let shared = NotificationScheduler()
    
    /// Private initializer to enforce singleton pattern
    private init() {}
    
    /// Schedules dream reminder notifications based on user preferences
    /// - Parameters:
    ///   - time: Time string in "HH:mm" format (e.g., "08:00")
    ///   - frequency: Frequency of reminders ("daily", "weekly", or "custom")
    ///   - archetype: Optional user archetype for personalized messages
    public func scheduleReminders(
        time: String,
        frequency: String,
        archetype: String? = nil
    ) async throws {
        let center = UNUserNotificationCenter.current()
        
        // Check if we have permission first
        let authStatus = await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus.rawValue)
            }
        }
        
        #if DEBUG
        print("📅 [SCHEDULER] Current authorization status: \(authStatus)")
        #endif
        
        guard authStatus == UNAuthorizationStatus.authorized.rawValue else {
            #if DEBUG
            print("⚠️ [SCHEDULER] Permission not granted (status: \(authStatus)), skipping scheduling")
            #endif
            return
        }
        
        #if DEBUG
        print("✅ [SCHEDULER] Permission confirmed, proceeding with scheduling...")
        #endif
        
        // Clear any existing dream reminders
        center.removePendingNotificationRequests(withIdentifiers: ["dream-reminder-daily"])
        
        // Parse the time string
        guard let dateComponents = parseTime(time) else {
            #if DEBUG
            print("⚠️ Invalid time format: \(time)")
            #endif
            return
        }
        
        // Create notification content
        let content = createNotificationContent(archetype: archetype)
        
        // Schedule based on frequency
        switch frequency {
        case "daily":
            try await scheduleDailyReminder(content: content, dateComponents: dateComponents)
        case "weekly":
            // For now, weekly will schedule for every Monday
            // This can be enhanced later to let users pick specific days
            try await scheduleWeeklyReminder(content: content, dateComponents: dateComponents)
        default:
            #if DEBUG
            print("⚠️ Unsupported frequency: \(frequency)")
            #endif
        }
        
        #if DEBUG
        print("✅ Scheduled \(frequency) reminder at \(time)")
        #endif
    }
    
    /// Cancels all scheduled dream reminders
    public func cancelAllReminders() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["dream-reminder-daily", "dream-reminder-weekly"])
        #if DEBUG
        print("✅ Cancelled all dream reminders")
        #endif
    }
    
    // MARK: - Private Helpers
    
    /// Parses a time string into DateComponents
    private func parseTime(_ time: String) -> DateComponents? {
        let parts = time.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else {
            return nil
        }
        
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return components
    }
    
    /// Creates personalized notification content based on user archetype
    private func createNotificationContent(archetype: String?) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Dream Capture Time"
        content.sound = .default
        
        // Personalize message based on archetype
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
        
        // Add action category (for future enhancement - quick record button)
        content.categoryIdentifier = "DREAM_REMINDER"
        
        return content
    }
    
    /// Schedules a daily repeating reminder
    private func scheduleDailyReminder(
        content: UNMutableNotificationContent,
        dateComponents: DateComponents
    ) async throws {
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )
        
        // Create request outside of async context to avoid sendability issues
        let identifier = "dream-reminder-daily"
        
        // Use the callback-based API to avoid sendability issues
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    /// Schedules a weekly reminder (currently defaults to Monday)
    private func scheduleWeeklyReminder(
        content: UNMutableNotificationContent,
        dateComponents: DateComponents
    ) async throws {
        var weeklyComponents = dateComponents
        weeklyComponents.weekday = 2 // Monday (1 = Sunday, 2 = Monday, etc.)
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: weeklyComponents,
            repeats: true
        )
        
        // Create request outside of async context to avoid sendability issues
        let identifier = "dream-reminder-weekly"
        
        // Use the callback-based API to avoid sendability issues
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}