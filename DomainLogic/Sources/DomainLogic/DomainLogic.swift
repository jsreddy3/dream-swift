import Foundation
import CoreModels               // the package you just finished

public protocol AudioRecorder: Sendable {
    func begin() async throws -> RecordingHandle
    func stop(_ handle: RecordingHandle) async throws -> CompletedSegment
}

public struct CompletedSegment: Sendable, Equatable {
    public let segmentID: UUID          // matches handle
    public let filename: String         // final file name
    public let duration: TimeInterval   // seconds
    public init(segmentID: UUID, filename: String, duration: TimeInterval) {
        self.segmentID = segmentID
        self.filename = filename
        self.duration = duration
    }
}

public struct RecordingHandle: Sendable, Equatable {
    public let segmentID: UUID
    
    public init(segmentID: UUID) {
        self.segmentID = segmentID
    }
}

/// DomainLogic
public protocol DreamStore: Sendable {
    func insertNew(_ dream: Dream) async throws
    func appendSegment(dreamID: UUID, segment: Segment) async throws
    func removeSegment(dreamID: UUID, segmentID: UUID) async throws
    func segments(dreamID: UUID) async throws -> [Segment]
    func getTranscript(dreamID: UUID) async throws -> String?
    func markCompleted(_ dreamID: UUID) async throws -> Dream
    func allDreams() async throws -> [Dream]
    func updateTitle(dreamID: UUID, title: String) async throws
    func updateSummary(dreamID: UUID, summary: String) async throws
    func updateTitleAndSummary(dreamID: UUID, title: String, summary: String) async throws
    func getVideoURL(dreamID: UUID) async throws -> URL?
    func getDream(_ id: UUID) async throws -> Dream         // NEW
    func requestAnalysis(for id: UUID, type: AnalysisType?) async throws
    func requestExpandedAnalysis(for id: UUID) async throws
    func deleteDream(_ id: UUID) async throws
    func generateImage(for id: UUID) async throws -> Dream
    
    @discardableResult
    func generateSummary(for id: UUID) async throws -> String
}

public extension DreamStore {
    // Make it optional for callers & for FileDreamStore.
    func requestAnalysis(for id: UUID, type: AnalysisType? = nil) async throws { }
    func requestExpandedAnalysis(for id: UUID) async throws { }
    func generateSummaryFallback(id: UUID, text: String) async throws {}
}
