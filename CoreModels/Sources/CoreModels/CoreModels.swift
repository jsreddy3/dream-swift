import Foundation

public enum DreamState: String, Codable, Sendable {
    case draft
    case completed
    case video_generated = "video_generated"
}

public enum AnalysisType: String, Codable, Sendable {
    case micro = "micro"           // ≤50 words: Brief reflection
    case short = "short"           // 51-200 words: Concise analysis  
    case medium = "medium"         // 201-500 words: Standard analysis
    case comprehensive = "comprehensive" // 501+ words: Detailed interpretation
    
    public var displayName: String {
        switch self {
        case .micro: return "Brief Reflection"
        case .short: return "Concise Analysis"
        case .medium: return "Standard Analysis"
        case .comprehensive: return "Comprehensive Interpretation"
        }
    }
    
    public var loadingMessage: String {
        switch self {
        case .micro: return "Generating brief reflection..."
        case .short: return "Creating concise analysis..."
        case .medium: return "Analyzing dream themes..."
        case .comprehensive: return "Crafting detailed interpretation..."
        }
    }
}

public struct Dream: Identifiable, Equatable, Sendable, Codable {
    public let id: UUID
    public var created_at: Date
    public var title: String
    public var transcript: String?
    public var segments: [Segment]
    public var state: DreamState
    public var videoS3Key: String?
    
    public var summary: String?
    public var additionalInfo: String?
    public var analysis: String?
    public var expandedAnalysis: String?
    
    // Image generation fields
    public var imageUrl: String?
    public var imagePrompt: String?
    public var imageGeneratedAt: Date?
    public var imageStatus: String?
    
    enum CodingKeys: String, CodingKey {
        case id, created_at, title, transcript, segments, state
        case videoS3Key = "video_s3_key"
        case summary
        case additionalInfo  = "additional_info"
        case analysis
        case expandedAnalysis = "expanded_analysis"
        case imageUrl = "image_url"
        case imagePrompt = "image_prompt"
        case imageGeneratedAt = "image_generated_at"
        case imageStatus = "image_status"
    }

    public init(
        id: UUID = UUID(),
        created_at: Date = Date(),
        title: String,
        transcript: String? = nil,
        segments: [Segment] = [],
        state: DreamState = .draft,
        videoS3Key: String? = nil,
        summary: String? = nil,
        additionalInfo: String? = nil,
        analysis: String? = nil,
        expandedAnalysis: String? = nil,
        imageUrl: String? = nil,
        imagePrompt: String? = nil,
        imageGeneratedAt: Date? = nil,
        imageStatus: String? = nil
    ) {
        self.id = id
        self.created_at = created_at
        self.title = title
        self.transcript = transcript
        self.segments = segments
        self.state = state
        self.videoS3Key = videoS3Key
        self.summary = summary
        self.additionalInfo = additionalInfo
        self.analysis = analysis
        self.expandedAnalysis = expandedAnalysis
        self.imageUrl = imageUrl
        self.imagePrompt = imagePrompt
        self.imageGeneratedAt = imageGeneratedAt
        self.imageStatus = imageStatus
    }

    // MARK: Codable
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id       = try c.decode(UUID.self, forKey: .id)
        if let ts = try c.decodeIfPresent(Date.self, forKey: .created_at) {
            created_at = ts
        } else {
            created_at = Date()
        }
        title     = try c.decode(String.self, forKey: .title)
        transcript = try c.decodeIfPresent(String.self, forKey: .transcript)
        segments   = try c.decodeIfPresent([Segment].self, forKey: .segments) ?? []
        state      = try c.decodeIfPresent(DreamState.self, forKey: .state) ?? .draft
        videoS3Key = try c.decodeIfPresent(String.self, forKey: .videoS3Key)
        summary    = try c.decodeIfPresent(String.self, forKey: .summary)
        additionalInfo = try c.decodeIfPresent(String.self, forKey: .additionalInfo)
        analysis   = try c.decodeIfPresent(String.self, forKey: .analysis)
        expandedAnalysis = try c.decodeIfPresent(String.self, forKey: .expandedAnalysis)
        imageUrl = try c.decodeIfPresent(String.self, forKey: .imageUrl)
        imagePrompt = try c.decodeIfPresent(String.self, forKey: .imagePrompt)
        imageGeneratedAt = try c.decodeIfPresent(Date.self, forKey: .imageGeneratedAt)
        imageStatus = try c.decodeIfPresent(String.self, forKey: .imageStatus)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(created_at, forKey: .created_at)    // always canonical out
        try c.encode(title, forKey: .title)
        try c.encode(segments, forKey: .segments)
        try c.encode(state, forKey: .state)
        try c.encodeIfPresent(transcript, forKey: .transcript)
        try c.encodeIfPresent(videoS3Key, forKey: .videoS3Key)
        try c.encodeIfPresent(summary, forKey: .summary)
        try c.encodeIfPresent(additionalInfo, forKey: .additionalInfo)
        try c.encodeIfPresent(analysis, forKey: .analysis)
        try c.encodeIfPresent(expandedAnalysis, forKey: .expandedAnalysis)
        try c.encodeIfPresent(imageUrl, forKey: .imageUrl)
        try c.encodeIfPresent(imagePrompt, forKey: .imagePrompt)
        try c.encodeIfPresent(imageGeneratedAt, forKey: .imageGeneratedAt)
        try c.encodeIfPresent(imageStatus, forKey: .imageStatus)
    }
    
    // MARK: - Content Analysis Utilities
    
    /// Calculate the word count of the dream content
    public var contentWordCount: Int {
        // Prefer transcript over summary for word count calculation
        let content = transcript ?? summary ?? ""
        guard !content.isEmpty else { return 0 }
        
        // Split by whitespace and count non-empty components
        return content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }
    
    /// Determine the appropriate analysis type based on content length
    public var suggestedAnalysisType: AnalysisType {
        let wordCount = contentWordCount
        
        switch wordCount {
        case 0...50:
            return .micro
        case 51...200:
            return .short
        case 201...500:
            return .medium
        default:
            return .comprehensive
        }
    }
    
    /// Get the primary content for analysis (transcript if available, otherwise summary)
    public var primaryContent: String {
        return transcript ?? summary ?? ""
    }
}

public enum SegmentModality: String, Codable, Sendable { case audio, text }

public struct Segment: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let modality: SegmentModality
    public let order: Int
    public let filename: String?          // audio-only
    public let duration: TimeInterval?    // audio-only
    public let text: String?              // text-only
    public let transcript: String?        // server transcript for audio

    public init(id: UUID,
                modality: SegmentModality,
                order: Int,
                filename: String? = nil,
                duration: TimeInterval? = nil,
                text: String? = nil,
                transcript: String? = nil) {
        self.id = id
        self.modality = modality
        self.order = order
        self.filename = filename
        self.duration = duration
        self.text = text
        self.transcript = transcript
    }

    // MARK: factories that read nicely at call-sites

    public static func audio(id: UUID = .init(),
                             filename: String,
                             duration: TimeInterval,
                             order: Int) -> Segment {
        Segment(id: id,
                modality: .audio,
                order: order,
                filename: filename,
                duration: duration,
                transcript: nil)
    }

    public static func text(id: UUID = .init(),
                            order: Int,
                            text: String) -> Segment {
        Segment(id: id,
                modality: .text,
                order: order,
                text: text,
                transcript: text)          // local echo until server merges
    }
}

