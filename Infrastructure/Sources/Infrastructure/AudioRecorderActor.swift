//
//  AudioRecorderActor.swift
//  Infrastructure
//
//  Created by DreamFinder.
//
#if os(iOS) || os(visionOS)        // 📱 compile only for iOS-family builds

import Foundation
import AVFoundation
import DomainLogic          // gives us AudioRecorder, RecordingHandle, CompletedSegment

/// Errors that may surface during the life-cycle of an audio capture session.
public enum RecorderError: Error, LocalizedError, Sendable {
    case permissionDenied
    case noActiveSession
    case underlying(Error)

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:   return "The microphone was not granted to the app."
        case .noActiveSession:    return "Attempted to stop a recording that was not started."
        case .underlying(let e):  return e.localizedDescription
        }
    }
}

/// Concrete AVFoundation-backed implementation of the AudioRecorder contract.
public actor AudioRecorderActor: AudioRecorder, Sendable {

    // MARK: – Private state

    private var recorder: AVAudioRecorder?
    private var currentURL: URL?

    // MARK: – Public API (AudioRecorder)
    
    public init() {}

    public func begin() async throws -> RecordingHandle {
        // 1. Request or validate permission up front.
        #if os(iOS)
        let granted: Bool
        if #available(iOS 17.0, *) {
            granted = await AVAudioApplication.requestRecordPermission()
        } else {
            granted = await withCheckedContinuation { cont in
                AVAudioSession.sharedInstance().requestRecordPermission { ok in
                    cont.resume(returning: ok)
                }
            }
        }
        guard granted else { throw RecorderError.permissionDenied }
        #endif
       

        // 2. Configure the shared audio session for speech-friendly capture.
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            throw RecorderError.underlying(error)
        }

        // 3. Generate a unique file URL in the app’s caches directory.
        let url = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        // 4. Create and start the AVAudioRecorder.
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 32_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64_000
        ]

        do {
            let newRecorder = try AVAudioRecorder(url: url, settings: settings)
            newRecorder.record()
            recorder = newRecorder
            currentURL = url
        } catch {
            throw RecorderError.underlying(error)
        }

        // 5. Hand the domain layer a fresh handle it can later correlate.
        return RecordingHandle(segmentID: UUID())
    }

    public func stop(_ handle: RecordingHandle) async throws -> CompletedSegment {
        guard let r = recorder, let url = currentURL else {
            throw RecorderError.noActiveSession
        }

        let duration = r.currentTime
        r.stop()

        // Clear state *before* returning in case caller immediately records again.
        recorder = nil
        currentURL = nil

        return CompletedSegment(segmentID: handle.segmentID,
                                filename: url.lastPathComponent,
                                duration: duration)
    }
}
#endif

#if os(macOS)
import Foundation
import DomainLogic

/// Dummy implementation so macOS unit tests and `swift test` can build.
public actor AudioRecorderActor: AudioRecorder, Sendable {
    public func begin() async throws -> RecordingHandle {
        throw NSError(domain: "Audio", code: 1,
                      userInfo: [NSLocalizedDescriptionKey:
                                 "Audio capture unavailable on macOS test build"])
    }
    public func stop(_ handle: RecordingHandle) async throws -> CompletedSegment {
        throw NSError(domain: "Audio", code: 1,
                      userInfo: [NSLocalizedDescriptionKey:
                                 "Audio capture unavailable on macOS test build"])
    }
}
#endif
