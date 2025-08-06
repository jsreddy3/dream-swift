import Foundation
import CoreModels
import Configuration

// MARK: - Remote Profile Store

/// Handles all profile-related API interactions
public actor RemoteProfileStore: Sendable {
    private let baseURL: URL
    private let auth: AuthStore
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    public init(
        baseURL: URL,
        auth: AuthStore
    ) {
        self.baseURL = baseURL
        self.auth = auth
        
        // Configure decoder - using explicit CodingKeys instead of snake_case conversion
        self.decoder = JSONDecoder()
        
        // Custom date decoding for mixed date formats
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let iso8601Formatter = DateFormatter()
        iso8601Formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        iso8601Formatter.timeZone = TimeZone(identifier: "UTC")
        
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Try ISO8601 with microseconds first (for lastCalculatedAt)
            if let date = iso8601Formatter.date(from: dateString) {
                return date
            }
            // Try simple date format (for lastDreamDate)
            if let date = dateFormatter.date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date from: \(dateString)")
        }
        
        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
    }
    
    // MARK: - Profile Methods
    
    /// Fetch the current user's profile
    public func profile() async throws -> UserProfile {
        let (data, _) = try await request("users/me/profile", method: "GET")
        print("DEBUG API: Raw response: \(String(data: data, encoding: .utf8) ?? "nil")")
        do {
            let profile = try decoder.decode(UserProfile.self, from: data)
            print("DEBUG API: Decode SUCCESS - name: '\(profile.name ?? "nil")'")
            return profile
        } catch {
            print("DEBUG API: Decode FAILED - error: \(error)")
            throw error
        }
    }
    
    /// Trigger profile calculation
    public func calculateProfile(force: Bool = false) async throws {
        struct CalculateRequest: Encodable {
            let forceRecalculate: Bool
        }
        
        let body = CalculateRequest(forceRecalculate: force)
        _ = try await request("users/me/profile/calculate", method: "POST", body: body)
    }
    
    // MARK: - Preferences Methods
    
    /// Fetch user preferences
    public func preferences() async throws -> UserPreferences {
        let (data, _) = try await request("users/me/preferences", method: "GET")
        return try decoder.decode(UserPreferences.self, from: data)
    }
    
    /// Create user preferences (during onboarding)
    public func createPreferences(_ preferences: UserPreferences) async throws -> UserPreferences {
        let (data, _) = try await request("users/me/preferences", method: "POST", body: preferences)
        return try decoder.decode(UserPreferences.self, from: data)
    }
    
    /// Update user preferences (partial update)
    public func updatePreferences(_ updates: [String: Any]) async throws -> UserPreferences {
        let (data, _) = try await requestWithDictionary("users/me/preferences", method: "PATCH", body: updates)
        return try decoder.decode(UserPreferences.self, from: data)
    }
    
    /// Suggest an archetype based on preferences
    public func suggestArchetype() async throws -> ArchetypeSuggestion {
        let (data, _) = try await request("users/me/preferences/suggest-archetype", method: "POST")
        return try decoder.decode(ArchetypeSuggestion.self, from: data)
    }
    
    /// Save initial archetype from onboarding
    public func saveInitialArchetype(archetype: String, confidence: Double) async throws {
        struct SaveArchetypeRequest: Encodable {
            let archetype: String
            let confidence: Double
        }
        
        let body = SaveArchetypeRequest(archetype: archetype, confidence: confidence)
        _ = try await request("users/me/profile/initial-archetype", method: "POST", body: body)
    }
    
    // MARK: - Private Helper Methods
    
    private func request(
        _ path: String,
        method: String,
        body: Encodable? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent(path))
        urlRequest.httpMethod = method
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add JWT if available
        if let token = auth.jwt {
            urlRequest.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Encode body if provided
        if let body = body {
            urlRequest.httpBody = try encoder.encode(body)
        }
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProfileStoreError.invalidResponse
        }
        
        // Check for success status codes
        switch httpResponse.statusCode {
        case 200...299:
            return (data, httpResponse)
        case 401:
            throw ProfileStoreError.unauthorized
        case 404:
            throw ProfileStoreError.notFound
        default:
            // Try to decode error message from response
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
                throw ProfileStoreError.serverError(errorResponse.detail)
            } else {
                throw ProfileStoreError.serverError("HTTP \(httpResponse.statusCode)")
            }
        }
    }
    
    private func requestWithDictionary(
        _ path: String,
        method: String,
        body: [String: Any]
    ) async throws -> (Data, HTTPURLResponse) {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent(path))
        urlRequest.httpMethod = method
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add JWT if available
        if let token = auth.jwt {
            urlRequest.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Encode dictionary body
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProfileStoreError.invalidResponse
        }
        
        // Check for success status codes
        switch httpResponse.statusCode {
        case 200...299:
            return (data, httpResponse)
        case 401:
            throw ProfileStoreError.unauthorized
        case 404:
            throw ProfileStoreError.notFound
        default:
            // Try to decode error message from response
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
                throw ProfileStoreError.serverError(errorResponse.detail)
            } else {
                throw ProfileStoreError.serverError("HTTP \(httpResponse.statusCode)")
            }
        }
    }
}

// MARK: - Error Types

public enum ProfileStoreError: LocalizedError, Sendable {
    case invalidResponse
    case unauthorized
    case notFound
    case serverError(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Authentication required"
        case .notFound:
            return "Profile not found"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}

// MARK: - Response Types

private struct ErrorResponse: Decodable {
    let detail: String
}

// MARK: - Profile Calculation Status

public enum ProfileCalculationStatus: String, Sendable {
    case pending
    case processing
    case completed
    case failed
}