// InfrastructureTests/AudioRecorderActorTests.swift
#if os(iOS)
import XCTest
import AVFoundation
import Infrastructure
import DomainLogic

@available(iOS 17, *)                 // compile & run only on iOS 17+
final class AudioRecorderActorTests: XCTestCase {

    func testBeginAndStopProduceNonEmptyFile() async throws {

        // Skip the whole test unless the user has already granted the mic.
        guard AVAudioApplication.shared.recordPermission == .granted else {
            throw XCTSkip("Microphone permission not granted.")
        }

        let recorder = AudioRecorderActor()          // add `public init()` in the actor
        let handle   = try await recorder.begin()

        try await Task.sleep(nanoseconds: 1_500_000_000)   // ~1.5 s

        let segment  = try await recorder.stop(handle)

        XCTAssertTrue(segment.filename.hasSuffix(".m4a"))
        XCTAssertGreaterThan(segment.duration, 1.0)

        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let fileURL = caches.appendingPathComponent(segment.filename)
        let size    = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber)?.intValue ?? 0
        XCTAssertGreaterThan(size, 2_000)                   // > 2 KB means real AAC data
    }
}
#endif
