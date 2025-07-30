import Foundation
import UIKit

/// Tracks the complete user journey through onboarding
@MainActor
public final class OnboardingJourneyTracker {
    // MARK: - Data Models
    
    public struct PageVisit: Codable, Sendable {
        let pageNumber: Int
        let pageName: String
        let visitedAt: Date
        var duration: TimeInterval?
        var actions: [String]
        
        enum CodingKeys: String, CodingKey {
            case pageNumber = "page_number"
            case pageName = "page_name"
            case visitedAt = "visited_at"
            case duration = "duration_seconds"
            case actions
        }
    }
    
    public struct PreferenceSelection: Codable, Sendable {
        let type: String
        let value: String
        let selectedAt: Date
        let page: String
        
        enum CodingKeys: String, CodingKey {
            case type
            case value
            case selectedAt = "selected_at"
            case page
        }
    }
    
    public struct NavigationEvent: Codable, Sendable {
        let action: String
        let fromPage: Int
        let toPage: Int?
        let timestamp: Date
        
        enum CodingKeys: String, CodingKey {
            case action
            case fromPage = "from_page"
            case toPage = "to_page"
            case timestamp
        }
    }
    
    public struct DeviceInfo: Codable, Sendable {
        let platform: String
        let version: String
        let model: String
    }
    
    public struct OnboardingJourney: Codable, Sendable {
        let onboardingVersion: String
        let startTime: Date
        var endTime: Date?
        var durationSeconds: Int?
        var completed: Bool
        var skipped: Bool
        var skippedAtPage: Int?
        var pages: [PageVisit]
        var preferencesSelected: [PreferenceSelection]
        var navigationEvents: [NavigationEvent]
        let deviceInfo: DeviceInfo
        
        enum CodingKeys: String, CodingKey {
            case onboardingVersion = "onboarding_version"
            case startTime = "start_time"
            case endTime = "end_time"
            case durationSeconds = "duration_seconds"
            case completed
            case skipped
            case skippedAtPage = "skipped_at_page"
            case pages
            case preferencesSelected = "preferences_selected"
            case navigationEvents = "navigation_events"
            case deviceInfo = "device_info"
        }
    }
    
    // MARK: - Properties
    
    private var journey: OnboardingJourney
    private var currentPageStartTime: Date?
    private let dateFormatter: ISO8601DateFormatter
    
    // MARK: - Initialization
    
    public init() {
        self.dateFormatter = ISO8601DateFormatter()
        
        // Get device info
        let device = UIDevice.current
        let deviceInfo = DeviceInfo(
            platform: "iOS",
            version: device.systemVersion,
            model: device.model
        )
        
        self.journey = OnboardingJourney(
            onboardingVersion: "1.0",
            startTime: Date(),
            endTime: nil,
            durationSeconds: nil,
            completed: false,
            skipped: false,
            skippedAtPage: nil,
            pages: [],
            preferencesSelected: [],
            navigationEvents: [],
            deviceInfo: deviceInfo
        )
    }
    
    // MARK: - Page Tracking
    
    public func trackPageVisit(pageNumber: Int, pageName: String) {
        // End timing for previous page
        if let startTime = currentPageStartTime,
           !journey.pages.isEmpty {
            let duration = Date().timeIntervalSince(startTime)
            journey.pages[journey.pages.count - 1].duration = duration
        }
        
        // Start timing for new page
        currentPageStartTime = Date()
        
        let pageVisit = PageVisit(
            pageNumber: pageNumber,
            pageName: pageName,
            visitedAt: Date(),
            duration: nil,
            actions: []
        )
        
        journey.pages.append(pageVisit)
    }
    
    public func trackPageAction(action: String) {
        guard !journey.pages.isEmpty else { return }
        journey.pages[journey.pages.count - 1].actions.append(action)
    }
    
    // MARK: - Navigation Tracking
    
    public func trackNavigation(action: String, fromPage: Int, toPage: Int? = nil) {
        let event = NavigationEvent(
            action: action,
            fromPage: fromPage,
            toPage: toPage,
            timestamp: Date()
        )
        journey.navigationEvents.append(event)
    }
    
    // MARK: - Preference Tracking
    
    public func trackPreferenceSelection(type: String, value: String, page: String) {
        let selection = PreferenceSelection(
            type: type,
            value: value,
            selectedAt: Date(),
            page: page
        )
        journey.preferencesSelected.append(selection)
    }
    
    // MARK: - Journey Completion
    
    public func completeJourney(skipped: Bool = false, skippedAtPage: Int? = nil) {
        // End timing for last page
        if let startTime = currentPageStartTime,
           !journey.pages.isEmpty {
            let duration = Date().timeIntervalSince(startTime)
            journey.pages[journey.pages.count - 1].duration = duration
        }
        
        journey.endTime = Date()
        journey.durationSeconds = Int(journey.endTime!.timeIntervalSince(journey.startTime))
        journey.completed = !skipped
        journey.skipped = skipped
        journey.skippedAtPage = skippedAtPage
    }
    
    // MARK: - Export
    
    public func exportJourney() -> OnboardingJourney {
        return journey
    }
    
    public func exportAsJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(journey)
    }
    
    public func exportAsDictionary() throws -> [String: Any] {
        let data = try exportAsJSON()
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        return json as? [String: Any] ?? [:]
    }
}