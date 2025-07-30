import Foundation

// MARK: - User Profile Models

public struct UserProfile: Sendable, Codable {
    public let archetype: String?
    public let archetypeConfidence: Double?
    public let statistics: ProfileStatistics
    public let emotionalMetrics: [EmotionalMetric]
    public let dreamThemes: [DreamTheme]
    public let recentSymbols: [String]
    public let lastCalculatedAt: Date?
    public let calculationStatus: String
    
    public init(
        archetype: String? = nil,
        archetypeConfidence: Double? = nil,
        statistics: ProfileStatistics,
        emotionalMetrics: [EmotionalMetric] = [],
        dreamThemes: [DreamTheme] = [],
        recentSymbols: [String] = [],
        lastCalculatedAt: Date? = nil,
        calculationStatus: String = "pending"
    ) {
        self.archetype = archetype
        self.archetypeConfidence = archetypeConfidence
        self.statistics = statistics
        self.emotionalMetrics = emotionalMetrics
        self.dreamThemes = dreamThemes
        self.recentSymbols = recentSymbols
        self.lastCalculatedAt = lastCalculatedAt
        self.calculationStatus = calculationStatus
    }
}

public struct ProfileStatistics: Sendable, Codable {
    public let totalDreams: Int
    public let totalDurationMinutes: Int
    public let dreamStreakDays: Int
    public let lastDreamDate: Date?
    
    enum CodingKeys: String, CodingKey {
        case totalDreams = "total_dreams"
        case totalDurationMinutes = "total_duration_minutes"
        case dreamStreakDays = "dream_streak_days"
        case lastDreamDate = "last_dream_date"
    }
    
    public init(
        totalDreams: Int = 0,
        totalDurationMinutes: Int = 0,
        dreamStreakDays: Int = 0,
        lastDreamDate: Date? = nil
    ) {
        self.totalDreams = totalDreams
        self.totalDurationMinutes = totalDurationMinutes
        self.dreamStreakDays = dreamStreakDays
        self.lastDreamDate = lastDreamDate
    }
}

public struct EmotionalMetric: Sendable, Codable {
    public let name: String
    public let intensity: Double
    public let color: String
    
    public init(name: String, intensity: Double, color: String) {
        self.name = name
        self.intensity = intensity
        self.color = color
    }
}

public struct DreamTheme: Sendable, Codable {
    public let name: String
    public let percentage: Int
    
    public init(name: String, percentage: Int) {
        self.name = name
        self.percentage = percentage
    }
}