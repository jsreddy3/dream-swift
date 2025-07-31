import Foundation
import CoreModels
import Infrastructure
import DomainLogic

// MARK: - Profile View Model

@MainActor
public class ProfileViewModel: ObservableObject {
    @Published var userProfile: UserProfile?
    @Published var currentArchetype: DreamArchetype = .analytical
    @Published var todayMessage: DreamMessage = DreamMessage(message: "", inspiration: "")
    @Published var recentSymbols: [String] = []
    @Published var emotionalData: [EmotionData] = []
    @Published var statistics: DreamStatistics = .empty
    @Published var isLoading = false
    @Published var isCalculating = false
    @Published var error: Error?
    @Published var isShowingCachedData = false
    @Published var cacheAge: String?
    @Published var dreamDates: [Date] = []
    
    private let profileStore: RemoteProfileStore
    private let dreamStore: DreamStore
    private let cache = ProfileCache()
    private var pollingTask: Task<Void, Never>?
    
    public init(
        profileStore: RemoteProfileStore,
        dreamStore: DreamStore
    ) {
        self.profileStore = profileStore
        self.dreamStore = dreamStore
    }
    
    public func loadProfile(forceCalculate: Bool = false) async {
        // First, try to load from cache for instant display
        if let cached = try? await cache.load() {
            self.userProfile = cached.profile
            updateUIFromProfile(cached.profile)
            self.isShowingCachedData = true
            self.cacheAge = cached.ageDescription
            
            // If cache is not expired and we're not forcing, we're done
            if !cached.isExpired && !forceCalculate {
                // Still load dream dates for the pattern chart
                await loadDreamDates()
                return
            }
        }
        
        // Now fetch from network
        isLoading = true
        error = nil
        
        do {
            // Force calculation if requested
            if forceCalculate {
                try await profileStore.calculateProfile(force: true)
                isCalculating = true
                startPollingForCompletion()
            }
            
            // Fetch profile
            let profile = try await profileStore.profile()
            
            // Only update UI if data has changed
            if profile.isDifferentFrom(self.userProfile) {
                self.userProfile = profile
                updateUIFromProfile(profile)
            }
            
            // Save to cache
            try? await cache.save(profile)
            
            // Clear cache indicators
            self.isShowingCachedData = false
            self.cacheAge = nil
            
            // Check if we need to start polling
            if profile.calculationStatus == "processing" {
                isCalculating = true
                startPollingForCompletion()
            }
            
            // Load dream dates for the pattern chart
            await loadDreamDates()
            
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
            
            // If we have cached data, keep showing it
            if userProfile != nil {
                // We already have data displayed, just show error indicator
                self.isShowingCachedData = true
                // Still load dream dates
                await loadDreamDates()
            } else {
                // No cached data, fallback to local calculation
                await loadProfileFromLocalDreams()
            }
        }
    }
    
    private func updateUIFromProfile(_ profile: UserProfile) {
        // Map backend archetype to frontend enum
        if let archetypeString = profile.archetype {
            self.currentArchetype = mapArchetype(from: archetypeString)
        }
        
        // Update today's message
        self.todayMessage = generateTodayMessage()
        
        // Map symbols
        self.recentSymbols = profile.recentSymbols
        
        // Map emotional metrics to wave data
        self.emotionalData = profile.emotionalMetrics.map { metric in
            EmotionData(
                name: metric.name,
                color: metric.color,
                intensity: metric.intensity,
                phase: Double.random(in: 0...2) // Random phase for wave animation
            )
        }
        
        // Map statistics
        let avgDuration = profile.statistics.totalDreams > 0 
            ? profile.statistics.totalDurationMinutes / profile.statistics.totalDreams 
            : 0
        self.statistics = DreamStatistics(
            totalDreams: profile.statistics.totalDreams,
            longestDream: avgDuration > 0 ? "\(avgDuration) minutes" : "N/A",
            topThemes: profile.dreamThemes.map { theme in
                DreamTheme(
                    id: UUID(),
                    name: theme.name,
                    percentage: theme.percentage
                )
            }
        )
    }
    
    private func mapArchetype(from string: String) -> DreamArchetype {
        switch string.lowercased() {
        case "analytical": return .analytical
        case "reflective": return .reflective
        case "introspective": return .introspective
        case "lucid": return .lucid
        case "creative": return .creative
        case "resolving": return .resolving
        // Legacy mappings for existing users
        case "starweaver": return .introspective
        case "moonwalker": return .lucid
        case "soulkeeper": return .reflective
        case "timeseeker": return .resolving
        case "shadowmender": return .resolving
        case "lightbringer": return .creative
        default: return .analytical
        }
    }
    
    private func startPollingForCompletion() {
        pollingTask?.cancel()
        
        pollingTask = Task {
            var attempts = 0
            let maxAttempts = 10 // Poll for up to 30 seconds
            
            while attempts < maxAttempts && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                
                do {
                    let profile = try await profileStore.profile()
                    if profile.calculationStatus == "completed" {
                        await MainActor.run {
                            self.userProfile = profile
                            self.updateUIFromProfile(profile)
                            self.isCalculating = false
                            self.isShowingCachedData = false
                            self.cacheAge = nil
                        }
                        // Save completed profile to cache
                        try? await cache.save(profile)
                        break
                    }
                } catch {
                    // Continue polling on error
                }
                
                attempts += 1
            }
            
            await MainActor.run {
                self.isCalculating = false
            }
        }
    }
    
    // MARK: - Fallback to Local Calculation
    
    private func loadProfileFromLocalDreams() async {
        do {
            let dreams = try await dreamStore.allDreams()
            
            await MainActor.run {
                self.currentArchetype = calculateArchetype(from: dreams)
                self.todayMessage = generateTodayMessage()
                self.recentSymbols = ["🌟", "🌊", "🦋"] // Default symbols
                self.emotionalData = generateDefaultEmotionalData()
                self.statistics = calculateStatistics(from: dreams)
                self.dreamDates = dreams.map { $0.created_at }
                self.isLoading = false
            }
        } catch {
            // Show empty state
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Local Calculation Helpers
    
    private func calculateArchetype(from dreams: [Dream]) -> DreamArchetype {
        // For MVP, use simple logic based on dream count and themes
        // Later: implement sophisticated analysis
        
        guard !dreams.isEmpty else { return .analytical }
        
        // Analyze dream titles and summaries for themes
        let allText = dreams.compactMap { dream in
            [dream.title, dream.summary].compactMap { $0 }.joined(separator: " ")
        }.joined(separator: " ").lowercased()
        
        // Simple keyword matching for MVP (updated for new archetypes)
        if allText.contains("fly") || allText.contains("control") || allText.contains("aware") {
            return .lucid
        } else if allText.contains("feel") || allText.contains("emotion") || allText.contains("heart") {
            return .reflective
        } else if allText.contains("symbol") || allText.contains("meaning") || allText.contains("deep") {
            return .introspective
        } else if allText.contains("solve") || allText.contains("problem") || allText.contains("work") {
            return .resolving
        } else if allText.contains("create") || allText.contains("imagine") || allText.contains("art") {
            return .creative
        }
        
        return .analytical // Default
    }
    
    // MARK: - Message Generation
    
    private func generateTodayMessage() -> DreamMessage {
        let messages = currentArchetype.messages
        guard !messages.isEmpty else {
            return DreamMessage(message: "", inspiration: "")
        }
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
    
    private func generateDefaultEmotionalData() -> [EmotionData] {
        // For MVP, generate sample wave data using design system colors
        // Later: analyze dream emotions
        return [
            EmotionData(name: "Joy", color: "FF9100", intensity: 0.7, phase: 0), // ember
            EmotionData(name: "Wonder", color: "800080", intensity: 0.5, phase: 1), // systemPurple
            EmotionData(name: "Peace", color: "8BC34A", intensity: 0.3, phase: 2) // systemGreen
        ]
    }
    
    // MARK: - Statistics
    
    private func calculateStatistics(from dreams: [Dream]) -> DreamStatistics {
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
    
    private func loadDreamDates() async {
        do {
            let dreams = try await dreamStore.allDreams()
            await MainActor.run {
                self.dreamDates = dreams.map { $0.created_at }
            }
        } catch {
            // If loading fails, keep empty array
            await MainActor.run {
                self.dreamDates = []
            }
        }
    }
}

// MARK: - Data Models

public struct DreamMessage: Sendable {
    let message: String
    let inspiration: String
}

public struct DreamArchetype: Sendable {
    let id: String
    let name: String
    let symbol: String
    let messages: [DreamMessage]
    let researcher: String
    let theory: String
    
    static let analytical = DreamArchetype(
        id: "analytical",
        name: "Analytical Dreamer",
        symbol: "🧠",
        messages: [
            DreamMessage(
                message: "Tonight your brain organizes today's challenges, making tomorrow's tasks clearer.",
                inspiration: "Interpretation inspired by psychologist Dr. Ernest Hartmann's research on memory consolidation during dreams."
            ),
            DreamMessage(
                message: "Your dreams may subtly rehearse practical scenarios tonight, enhancing tomorrow's problem-solving skills.",
                inspiration: "Based on psychologist Dr. Antti Revonsuo's threat-simulation theory of dreaming."
            ),
            DreamMessage(
                message: "Tonight's dreams integrate new information quietly. Tomorrow, note any improved clarity or understanding.",
                inspiration: "Guided by sleep researcher Dr. Robert Stickgold's studies on learning and dream integration."
            )
        ],
        researcher: "Dr. Ernest Hartmann",
        theory: "Thick-Boundary Dreaming Theory"
    )
    
    static let reflective = DreamArchetype(
        id: "reflective",
        name: "Reflective Dreamer",
        symbol: "🌊",
        messages: [
            DreamMessage(
                message: "Tonight your dreams may gently process emotions, helping you wake up feeling clearer.",
                inspiration: "Inspired by dream researcher Dr. Rosalind Cartwright's work on dreams and emotional resilience."
            ),
            DreamMessage(
                message: "Dreams tonight could reflect interpersonal dynamics. Tomorrow, consider new emotional insights.",
                inspiration: "Based on psychologist Dr. Calvin Hall's studies of relationships and dream content."
            ),
            DreamMessage(
                message: "Your dreams may explore deep feelings tonight, guiding emotional adaptation and balance.",
                inspiration: "Influenced by psychiatrist Dr. Milton Kramer's theory of dreams aiding emotional problem-solving."
            )
        ],
        researcher: "Dr. Rosalind Cartwright",
        theory: "Dreams as Emotional Adaptation"
    )
    
    static let introspective = DreamArchetype(
        id: "introspective",
        name: "Introspective Dreamer",
        symbol: "🔍",
        messages: [
            DreamMessage(
                message: "Tonight's symbolic dreams could illuminate hidden aspects of your inner world.",
                inspiration: "Inspired by psychologist Dr. Carl Jung's work on dream symbolism and the unconscious."
            ),
            DreamMessage(
                message: "Your vivid dreams tonight may reveal insights about your subconscious concerns.",
                inspiration: "Based on psychologist Dr. Michael Schredl's research linking dream recall to personality traits."
            ),
            DreamMessage(
                message: "Dream imagery tonight might reflect your deepest values and intuitions.",
                inspiration: "Interpretation influenced by psychologist Dr. Clara Hill's dream meaning exploration methods."
            )
        ],
        researcher: "Dr. Michael Schredl",
        theory: "Dream Recall and Personality Research"
    )
    
    static let lucid = DreamArchetype(
        id: "lucid",
        name: "Lucid Dreamer",
        symbol: "🌀",
        messages: [
            DreamMessage(
                message: "Tonight, set a gentle intention: 'I'll become aware that I'm dreaming.'",
                inspiration: "Inspired by psychophysiologist Dr. Stephen LaBerge's techniques on inducing lucid dreams."
            ),
            DreamMessage(
                message: "Your dreams tonight could offer an opportunity to consciously explore your dreamscape.",
                inspiration: "Based on neuroscientist Dr. Benjamin Baird's research on awareness during dreams."
            ),
            DreamMessage(
                message: "Before sleep, calmly remind yourself to notice dream signs. Tonight awareness is within reach.",
                inspiration: "Guided by psychologist Dr. Ursula Voss's work on lucid dreaming and brain states."
            )
        ],
        researcher: "Dr. Stephen LaBerge",
        theory: "Lucid Dreaming and Metacognition"
    )
    
    static let creative = DreamArchetype(
        id: "creative",
        name: "Creative Dreamer",
        symbol: "🎨",
        messages: [
            DreamMessage(
                message: "Tonight your dreams may creatively blend ideas, inspiring fresh insights upon waking.",
                inspiration: "Interpretation based on psychologist Dr. Ernest Hartmann's thin-boundary dreaming theory."
            ),
            DreamMessage(
                message: "Expect imaginative dreams tonight. Tomorrow, capture ideas sparked in your sleep.",
                inspiration: "Inspired by neuroscientist Dr. Robert Stickgold's findings on creativity and dreaming."
            ),
            DreamMessage(
                message: "Your dreams tonight might reveal unexpected connections. Stay open to morning inspiration.",
                inspiration: "Influenced by psychologist Dr. Deirdre Barrett's research on creative problem-solving through dreams."
            )
        ],
        researcher: "Dr. Ernest Hartmann",
        theory: "Thin-Boundary Dreaming Theory"
    )
    
    static let resolving = DreamArchetype(
        id: "resolving",
        name: "Resolving Dreamer",
        symbol: "⚙️",
        messages: [
            DreamMessage(
                message: "Tonight your mind naturally rehearses solutions. Tomorrow, reflect on new approaches to current challenges.",
                inspiration: "Inspired by psychologist Dr. G. William Domhoff's work on dreams as problem-solving rehearsals."
            ),
            DreamMessage(
                message: "Dreams tonight might simulate future scenarios, quietly preparing you for upcoming events.",
                inspiration: "Based on psychologist Dr. Antti Revonsuo's simulation theory of dreaming."
            ),
            DreamMessage(
                message: "Your dreams tonight could clarify unresolved issues, helping you awaken with clearer direction.",
                inspiration: "Influenced by psychologist Dr. Rosalind Cartwright's findings on dreams and conflict resolution."
            )
        ],
        researcher: "Dr. G. William Domhoff",
        theory: "Dreams as Problem-solving Mechanisms"
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