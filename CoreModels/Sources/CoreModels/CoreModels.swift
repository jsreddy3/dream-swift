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
    public var segments: [Segment]
    public var state: DreamState
    public var videoS3Key: String?
    
    public var summary: String?
    public var additionalInfo: String?
    public var analysis: String?
    
    enum CodingKeys: String, CodingKey {
        case id, created, title, transcript, segments, state
        case videoS3Key = "video_s3_key"
        case summary
        case additionalInfo  = "additional_info"
        case analysis
    }

    public init(
        id: UUID = UUID(),
        created: Date = Date(),
        title: String,
        transcript: String? = nil,
        segments: [Segment] = [],
        state: DreamState = .draft,
        videoS3Key: String? = nil,
        summary: String? = nil,
        additionalInfo: String? = nil,
        analysis: String? = nil
    ) {
        self.id = id
        self.created = created
        self.title = title
        self.transcript = transcript
        self.segments = segments
        self.state = state
        self.videoS3Key = videoS3Key
        self.summary = summary
        self.additionalInfo = additionalInfo
        self.analysis = analysis
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

