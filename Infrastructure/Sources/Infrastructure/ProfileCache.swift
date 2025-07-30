import Foundation
import CoreModels

// MARK: - Profile Cache

/// Manages local caching of user profile data for offline access
public actor ProfileCache {
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // Cache keys
    private enum CacheKey {
        static let profile = "com.dreamapp.profile.cached"
        static let lastFetch = "com.dreamapp.profile.lastFetch"
        static let cacheVersion = "com.dreamapp.profile.cacheVersion"
    }
    
    // Current cache version - increment if cache structure changes
    private let currentCacheVersion = 1
    
    // Cache validity duration (24 hours)
    private let cacheValidityDuration: TimeInterval = 24 * 60 * 60
    
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        
        // Configure encoder/decoder
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        
        // Check cache version and clear if outdated
        Task {
            await checkCacheVersion()
        }
    }
    
    // MARK: - Public Methods
    
    /// Save profile to cache
    public func save(_ profile: UserProfile) async throws {
        let data = try encoder.encode(profile)
        userDefaults.set(data, forKey: CacheKey.profile)
        userDefaults.set(Date(), forKey: CacheKey.lastFetch)
        userDefaults.set(currentCacheVersion, forKey: CacheKey.cacheVersion)
    }
    
    /// Load profile from cache
    public func load() async throws -> CachedProfile? {
        guard let data = userDefaults.data(forKey: CacheKey.profile),
              let lastFetch = userDefaults.object(forKey: CacheKey.lastFetch) as? Date else {
            return nil
        }
        
        let profile = try decoder.decode(UserProfile.self, from: data)
        let isExpired = Date().timeIntervalSince(lastFetch) > cacheValidityDuration
        
        return CachedProfile(
            profile: profile,
            cachedAt: lastFetch,
            isExpired: isExpired
        )
    }
    
    /// Clear all cached data
    public func clear() async {
        userDefaults.removeObject(forKey: CacheKey.profile)
        userDefaults.removeObject(forKey: CacheKey.lastFetch)
        userDefaults.removeObject(forKey: CacheKey.cacheVersion)
    }
    
    /// Check if cache exists
    public func exists() async -> Bool {
        return userDefaults.data(forKey: CacheKey.profile) != nil
    }
    
    // MARK: - Private Methods
    
    private func checkCacheVersion() async {
        let savedVersion = userDefaults.integer(forKey: CacheKey.cacheVersion)
        if savedVersion != currentCacheVersion && savedVersion != 0 {
            // Cache version mismatch, clear old cache
            await clear()
        }
    }
}

// MARK: - Cached Profile Model

public struct CachedProfile: Sendable {
    public let profile: UserProfile
    public let cachedAt: Date
    public let isExpired: Bool
    
    /// Time since cache was saved
    public var age: TimeInterval {
        Date().timeIntervalSince(cachedAt)
    }
    
    /// Human-readable cache age
    public var ageDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: cachedAt, relativeTo: Date())
    }
}

// MARK: - Convenience Extensions

public extension UserProfile {
    /// Check if this profile differs significantly from another
    func isDifferentFrom(_ other: UserProfile?) -> Bool {
        guard let other = other else { return true }
        
        // Check key fields that would warrant a UI update
        return archetype != other.archetype ||
               statistics.totalDreams != other.statistics.totalDreams ||
               statistics.dreamStreakDays != other.statistics.dreamStreakDays ||
               emotionalMetrics.count != other.emotionalMetrics.count ||
               dreamThemes.count != other.dreamThemes.count
    }
}