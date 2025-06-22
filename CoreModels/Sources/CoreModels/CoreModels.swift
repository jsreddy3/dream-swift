import Foundation

public enum DreamState: String, Codable, Sendable {
    case draft
    case completed
    case video_generated = "video_generated"
}

public struct Dream: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var created: Date
    public var title: String
    public var transcript: String?
    public var segments: [AudioSegment]
    public var state: DreamState
    public var videoS3Key: String?
    
    enum CodingKeys: String, CodingKey {
        case id, created, title, transcript, segments, state
        case videoS3Key = "video_s3_key"
    }

    public init(
        id: UUID = UUID(),
        created: Date = Date(),
        title: String,
        transcript: String? = nil,
        segments: [AudioSegment] = [],
        state: DreamState = .draft,
        videoS3Key: String? = nil
    ) {
        self.id = id
        self.created = created
        self.title = title
        self.transcript = transcript
        self.segments = segments
        self.state = state
        self.videoS3Key = videoS3Key
    }
}

public struct AudioSegment: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let filename: String
    public let duration: TimeInterval
    public let order: Int
    public let transcript: String?

    public init(
        id: UUID = UUID(),
        filename: String,
        duration: TimeInterval,
        order: Int,
        transcript: String? = nil
    ) {
        self.id = id
        self.filename = filename
        self.duration = duration
        self.order = order
        self.transcript = transcript
    }
}
