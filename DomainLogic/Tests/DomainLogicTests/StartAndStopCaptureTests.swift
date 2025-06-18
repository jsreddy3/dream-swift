// DomainLogicTests/StartAndStopCaptureTests.swift
import XCTest
import DomainLogic
import CoreModels

// MARK: – Test doubles

private actor FakeAudioRecorder: AudioRecorder {
    let beginID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
    private(set) var lastStoppedHandle: RecordingHandle?

    func begin() async throws -> RecordingHandle {
        return RecordingHandle(segmentID: beginID)
    }

    func stop(_ handle: RecordingHandle) async throws -> CompletedSegment {
        lastStoppedHandle = handle
        return CompletedSegment(segmentID: handle.segmentID,
                                filename: "dream.m4a",
                                duration: 9.5)
    }
}

private actor InMemoryDreamStore: DreamStore {
    private(set) var inserted: Dream?
    private(set) var appended: (dreamID: UUID, segment: AudioSegment)?

    func insertNew(_ dream: Dream) async throws {
        inserted = dream
    }

    func appendSegment(dreamID: UUID, segment: AudioSegment) async throws {
        appended = (dreamID, segment)
    }

    func markCompleted(_ dreamID: UUID) async throws { /* unused for now */ }
}

// MARK: – Tests

final class StartAndStopCaptureTests: XCTestCase {

    func testStartCaptureInsertsDreamWithInitialSegment() async throws {
        let recorder = FakeAudioRecorder()
        let store = InMemoryDreamStore()
        let useCase = StartCaptureDream(recorder: recorder, store: store)

        let (dreamID, _) = try await useCase()                        // ← callAsFunction

        let saved = await store.inserted
        XCTAssertEqual(dreamID, saved?.id)
        XCTAssertEqual(saved?.segments.count, 0)
    }

    func testStopCaptureAppendsCompletedSegment() async throws {
        // given an already-persisted dream
        let existingDream = Dream(title: "Test", segments: [])
        let recorder = FakeAudioRecorder()
        let store = InMemoryDreamStore()
        try await store.insertNew(existingDream)

        // when we stop recording
        let stopUseCase = StopCaptureDream(recorder: recorder, store: store)
        let handle = RecordingHandle(segmentID:
                      UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!)
        try await stopUseCase(dreamID: existingDream.id,
                              handle: handle,
                              order: 0)

        // then the store received the new segment with correct metadata
        let appended = await store.appended
        XCTAssertNotNil(appended)
        XCTAssertEqual(appended?.dreamID, existingDream.id)
        if let seg = appended?.segment {
            XCTAssertEqual(seg.id, handle.segmentID)
            XCTAssertEqual(seg.filename, "dream.m4a")
            XCTAssertEqual(seg.duration, 9.5, accuracy: 0.01)
            XCTAssertEqual(seg.order, 0)
        }
    }
}
