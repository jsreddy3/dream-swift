import Foundation

public enum DreamState: String, Codable, Sendable {
    case draft
    case completed
}

public struct Dream: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var created: Date
    public var title: String
    public var transcript: String?
    public var segments: [AudioSegment]
    public var state: DreamState                     // ← new

    public init(
        id: UUID = UUID(),
        created: Date = Date(),
        title: String,
        transcript: String? = nil,
        segments: [AudioSegment] = [],
        state: DreamState = .draft
    ) {
        self.id = id
        self.created = created
        self.title = title
        self.transcript = transcript
        self.segments = segments
        self.state = state
    }
}

public struct AudioSegment: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let filename: String
    public let duration: TimeInterval
    public let order: Int

    public init(
        id: UUID = UUID(),
        filename: String,
        duration: TimeInterval,
        order: Int
    ) {
        self.id = id
        self.filename = filename
        self.duration = duration
        self.order = order
    }
}
