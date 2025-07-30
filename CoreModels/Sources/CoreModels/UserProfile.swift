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

// MARK: - User Preferences Models

public struct UserPreferences: Sendable, Codable {
    public let id: UUID?
    public let userId: UUID?
    
    // Sleep patterns
    public let typicalBedtime: String?
    public let typicalWakeTime: String?
    public let sleepQuality: String?
    
    // Dream patterns
    public let dreamRecallFrequency: String?
    public let dreamVividness: String?
    public let commonDreamThemes: [String]
    
    // Goals & interests
    public let primaryGoal: String?
    public let interests: [String]
    
    // Notifications
    public let reminderEnabled: Bool
    public let reminderTime: String?
    public let reminderFrequency: String
    public let reminderDays: [String]
    
    // Personalization
    public let initialArchetype: String?
    public let personalityTraits: [String: String]
    public let onboardingCompleted: Bool
    
    // Timestamps
    public let createdAt: Date?
    public let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, userId = "user_id"
        case typicalBedtime = "typical_bedtime"
        case typicalWakeTime = "typical_wake_time"
        case sleepQuality = "sleep_quality"
        case dreamRecallFrequency = "dream_recall_frequency"
        case dreamVividness = "dream_vividness"
        case commonDreamThemes = "common_dream_themes"
        case primaryGoal = "primary_goal"
        case interests
        case reminderEnabled = "reminder_enabled"
        case reminderTime = "reminder_time"
        case reminderFrequency = "reminder_frequency"
        case reminderDays = "reminder_days"
        case initialArchetype = "initial_archetype"
        case personalityTraits = "personality_traits"
        case onboardingCompleted = "onboarding_completed"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    public init(
        id: UUID? = nil,
        userId: UUID? = nil,
        typicalBedtime: String? = nil,
        typicalWakeTime: String? = nil,
        sleepQuality: String? = nil,
        dreamRecallFrequency: String? = nil,
        dreamVividness: String? = nil,
        commonDreamThemes: [String] = [],
        primaryGoal: String? = nil,
        interests: [String] = [],
        reminderEnabled: Bool = true,
        reminderTime: String? = nil,
        reminderFrequency: String = "daily",
        reminderDays: [String] = [],
        initialArchetype: String? = nil,
        personalityTraits: [String: String] = [:],
        onboardingCompleted: Bool = false,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.typicalBedtime = typicalBedtime
        self.typicalWakeTime = typicalWakeTime
        self.sleepQuality = sleepQuality
        self.dreamRecallFrequency = dreamRecallFrequency
        self.dreamVividness = dreamVividness
        self.commonDreamThemes = commonDreamThemes
        self.primaryGoal = primaryGoal
        self.interests = interests
        self.reminderEnabled = reminderEnabled
        self.reminderTime = reminderTime
        self.reminderFrequency = reminderFrequency
        self.reminderDays = reminderDays
        self.initialArchetype = initialArchetype
        self.personalityTraits = personalityTraits
        self.onboardingCompleted = onboardingCompleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct ArchetypeSuggestion: Sendable, Codable {
    public let suggestedArchetype: String
    public let confidence: Double
    public let archetypeDetails: ArchetypeDetails
    
    enum CodingKeys: String, CodingKey {
        case suggestedArchetype = "suggested_archetype"
        case confidence
        case archetypeDetails = "archetype_details"
    }
    
    public init(suggestedArchetype: String, confidence: Double, archetypeDetails: ArchetypeDetails) {
        self.suggestedArchetype = suggestedArchetype
        self.confidence = confidence
        self.archetypeDetails = archetypeDetails
    }
}

public struct ArchetypeDetails: Sendable, Codable {
    public let name: String
    public let symbol: String
    public let description: String
    
    public init(name: String, symbol: String, description: String) {
        self.name = name
        self.symbol = symbol
        self.description = description
    }
}