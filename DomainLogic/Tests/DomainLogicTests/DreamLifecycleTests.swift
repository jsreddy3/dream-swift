// DomainLogicTests/ContinueDreamLifecycleTests.swift
import XCTest
import DomainLogic
import CoreModels

private actor SequencedFakeRecorder: AudioRecorder {
    private var counter = 0
    func begin() async throws -> RecordingHandle {
        counter += 1
        let id = UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", counter))")!
        return RecordingHandle(segmentID: id)
    }
    func stop(_ handle: RecordingHandle) async throws -> CompletedSegment {
        return CompletedSegment(segmentID: handle.segmentID,
                                filename: "seg\(counter).m4a",
                                duration: Double(counter))          // 1 s, 2 s, 3 s
    }
}

private actor TrackingDreamStore: DreamStore {
    private(set) var insertedDream: Dream?
    private(set) var appendedSegments: [AudioSegment] = []
    private(set) var completedID: UUID?
    func insertNew(_ dream: Dream) async throws { insertedDream = dream }
    func appendSegment(dreamID: UUID, segment: AudioSegment) async throws { appendedSegments.append(segment) }
    func markCompleted(_ dreamID: UUID) async throws { completedID = dreamID }
}

final class ContinueDreamLifecycleTests: XCTestCase {
    func testStartStopStartStopStartStopCompleteFlow() async throws {
        let recorder = SequencedFakeRecorder()
        let store = TrackingDreamStore()

        let start = StartCaptureDream(recorder: recorder, store: store)
        let stop  = StopCaptureDream(recorder: recorder, store: store)
        let cont  = StartAdditionalSegment(recorder: recorder, store: store)
        let done  = CompleteDream(store: store)

        // first segment
        let (dreamID, firstHandle) = try await start()
        try await stop(dreamID: dreamID, handle: firstHandle, order: 0)

        // second segment
        let secondHandle = try await cont(dreamID: dreamID)
        try await stop(dreamID: dreamID, handle: secondHandle, order: 1)

        // third segment
        let thirdHandle = try await cont(dreamID: dreamID)
        try await stop(dreamID: dreamID, handle: thirdHandle, order: 2)

        // completion
        try await done(dreamID: dreamID)
        

        // assertions
        let segments = await store.appendedSegments
        let completed = await store.completedID
        XCTAssertEqual(segments.count, 3)
        XCTAssertEqual(segments[0].filename, "seg1.m4a")
        XCTAssertEqual(segments[1].filename, "seg2.m4a")
        XCTAssertEqual(segments[2].filename, "seg3.m4a")
        XCTAssertEqual(completed, dreamID)
    }
}
