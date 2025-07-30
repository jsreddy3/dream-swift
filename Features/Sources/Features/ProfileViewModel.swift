import Foundation
import CoreModels
import Infrastructure
import DomainLogic

// MARK: - Profile View Model

@MainActor
public class ProfileViewModel: ObservableObject {
    @Published var currentArchetype: DreamArchetype = .starweaver
    @Published var todayMessage: String = ""
    @Published var recentSymbols: [String] = []
    @Published var emotionalData: [EmotionData] = []
    @Published var statistics: DreamStatistics = .empty
    @Published var isLoading = false
    
    private let store: DreamStore
    private var dreams: [Dream] = []
    
    public init(store: DreamStore) {
        self.store = store
    }
    
    public func loadProfile() async {
        isLoading = true
        
        do {
            // Load all dreams
            dreams = try await store.allDreams()
            
            // Calculate profile data
            await MainActor.run {
                self.currentArchetype = calculateArchetype()
                self.todayMessage = generateTodayMessage()
                self.recentSymbols = extractRecentSymbols()
                self.emotionalData = generateEmotionalData()
                self.statistics = calculateStatistics()
                self.isLoading = false
            }
        } catch {
            #if DEBUG
            print("Failed to load profile: \(error)")
            #endif
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Archetype Calculation
    
    private func calculateArchetype() -> DreamArchetype {
        // For MVP, use simple logic based on dream count and themes
        // Later: implement sophisticated analysis
        
        guard !dreams.isEmpty else { return .starweaver }
        
        // Analyze dream titles and summaries for themes
        let allText = dreams.compactMap { dream in
            [dream.title, dream.summary].compactMap { $0 }.joined(separator: " ")
        }.joined(separator: " ").lowercased()
        
        // Simple keyword matching for MVP
        if allText.contains("fly") || allText.contains("travel") || allText.contains("journey") {
            return .moonwalker
        } else if allText.contains("feel") || allText.contains("emotion") || allText.contains("heart") {
            return .soulkeeper
        } else if allText.contains("past") || allText.contains("memory") || allText.contains("future") {
            return .timeseeker
        } else if allText.contains("dark") || allText.contains("fear") || allText.contains("shadow") {
            return .shadowmender
        } else if allText.contains("light") || allText.contains("joy") || allText.contains("happy") {
            return .lightbringer
        }
        
        return .starweaver // Default
    }
    
    // MARK: - Message Generation
    
    private func generateTodayMessage() -> String {
        let messages = currentArchetype.messages
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        let index = dayOfYear % messages.count
        return messages[index]
    }
    
    // MARK: - Symbol Extraction
    
    private func extractRecentSymbols() -> [String] {
        // For MVP, return common dream symbols
        // Later: extract from actual dream content
        let allSymbols = ["🌊", "💎", "🦋", "🌙", "⭐", "🔥", "🌺", "🦅", "🗝️", "🌈"]
        return Array(allSymbols.shuffled().prefix(3))
    }
    
    // MARK: - Emotional Data
    
    private func generateEmotionalData() -> [EmotionData] {
        // For MVP, generate sample wave data using design system colors
        // Later: analyze dream emotions
        return [
            EmotionData(name: "Joy", color: "FF9100", intensity: 0.7, phase: 0), // ember
            EmotionData(name: "Wonder", color: "800080", intensity: 0.5, phase: 1), // systemPurple
            EmotionData(name: "Peace", color: "8BC34A", intensity: 0.3, phase: 2) // systemGreen
        ]
    }
    
    // MARK: - Statistics
    
    private func calculateStatistics() -> DreamStatistics {
        guard !dreams.isEmpty else { return .empty }
        
        // Calculate longest dream
        let longestDream = dreams
            .compactMap { dream -> (Dream, TimeInterval)? in
                guard let duration = calculateDreamDuration(dream) else { return nil }
                return (dream, duration)
            }
            .max { $0.1 < $1.1 }
        
        let longestDreamText = longestDream.map { dream, duration in
            let minutes = Int(duration / 60)
            return "\(minutes) minutes"
        } ?? "N/A"
        
        // Calculate themes (simplified for MVP)
        let themes = [
            DreamTheme(id: UUID(), name: "Adventure", percentage: 40),
            DreamTheme(id: UUID(), name: "Family", percentage: 30),
            DreamTheme(id: UUID(), name: "Mystery", percentage: 30)
        ]
        
        return DreamStatistics(
            totalDreams: dreams.count,
            longestDream: longestDreamText,
            topThemes: themes
        )
    }
    
    private func calculateDreamDuration(_ dream: Dream) -> TimeInterval? {
        // Sum up audio segment durations
        let totalDuration = dream.segments
            .compactMap { $0.duration }
            .reduce(0, +)
        
        return totalDuration > 0 ? totalDuration : nil
    }
}

// MARK: - Data Models

public struct DreamArchetype: Sendable {
    let id: String
    let name: String
    let symbol: String
    let messages: [String]
    
    static let starweaver = DreamArchetype(
        id: "starweaver",
        name: "Starweaver",
        symbol: "🌟",
        messages: [
            "Symbols dance through your sleep tonight",
            "Your dreams weave stories yet untold",
            "The cosmos speaks through your slumber",
            "Intricate patterns emerge in your rest",
            "Tonight's dreams hold ancient wisdom"
        ]
    )
    
    static let moonwalker = DreamArchetype(
        id: "moonwalker",
        name: "Moonwalker",
        symbol: "🌙",
        messages: [
            "New paths await in tonight's journey",
            "Your dream feet know ancient roads",
            "Adventure calls from beyond the veil",
            "Traverse the landscapes of your mind",
            "Tonight you walk between worlds"
        ]
    )
    
    static let soulkeeper = DreamArchetype(
        id: "soulkeeper",
        name: "Soulkeeper",
        symbol: "💫",
        messages: [
            "Deep waters reflect your inner truth",
            "Emotions rise like tides in sleep",
            "Your heart speaks clearest at night",
            "Dreams reveal what daylight hides",
            "Tonight's rest brings emotional clarity"
        ]
    )
    
    static let timeseeker = DreamArchetype(
        id: "timeseeker",
        name: "Timeseeker",
        symbol: "⏳",
        messages: [
            "Past and future merge in dreams",
            "Time bends within your sleeping mind",
            "Memories transform into prophecies",
            "Yesterday's echoes meet tomorrow's call",
            "Dreams transcend temporal boundaries"
        ]
    )
    
    static let shadowmender = DreamArchetype(
        id: "shadowmender",
        name: "Shadowmender",
        symbol: "🌑",
        messages: [
            "Darkness holds your greatest strength",
            "Fear becomes wisdom in your dreams",
            "Shadows teach what light cannot",
            "Transform challenges into power tonight",
            "Your dreams alchemize the darkness"
        ]
    )
    
    static let lightbringer = DreamArchetype(
        id: "lightbringer",
        name: "Lightbringer",
        symbol: "☀️",
        messages: [
            "Joy illuminates your dream path",
            "You carry dawn within your rest",
            "Light flows through your sleeping soul",
            "Dreams of hope and healing await",
            "Tonight's visions bring renewal"
        ]
    )
}

public struct EmotionData: Identifiable, Sendable {
    public let id = UUID()
    let name: String
    let color: String
    let intensity: Double // 0.0 to 1.0
    let phase: Double // For wave animation offset
}

public struct DreamTheme: Identifiable, Sendable {
    public let id: UUID
    let name: String
    let percentage: Int
}

public struct DreamStatistics: Sendable {
    let totalDreams: Int
    let longestDream: String
    let topThemes: [DreamTheme]
    
    static let empty = DreamStatistics(
        totalDreams: 0,
        longestDream: "N/A",
        topThemes: []
    )
}