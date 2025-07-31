//
//  ContinuousAudioRecorder.swift
//  Infrastructure
//
//  Continuous recording implementation for Phase 2
//  Supports long recordings with checkpoint system
//

#if os(iOS) || os(visionOS)

import Foundation
import AVFoundation
import DomainLogic
import Configuration

/// Metadata for checkpoint system
private struct RecordingCheckpoint: Codable {
    let dreamID: UUID
    let startTime: Date
    let lastCheckpoint: Date
    let checkpointCount: Int
    let fileURL: URL
}

/// Extended recorder that supports continuous recording
public actor ContinuousAudioRecorder: AudioRecorder, Sendable {
    
    // MARK: - State
    
    private var recorder: AVAudioRecorder?
    private var currentURL: URL?
    private var recordingStartTime: Date?
    private var dreamID: UUID?
    private var checkpointTask: Task<Void, Never>?
    private var currentCheckpoint: RecordingCheckpoint?
    
    // Checkpoint interval (30 seconds as per plan)
    private let checkpointInterval: TimeInterval = 30.0
    
    // MARK: - Logging
    
    private func log(_ message: String, level: String = "INFO") {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[ContinuousRecorder] [\(level)] [\(timestamp)] \(message)")
    }
    
    // MARK: - Public API
    
    public init() {}
    
    public func begin() async throws -> RecordingHandle {
        log("begin() called - continuous recording mode")
        
        // For preview/testing
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            log("Preview mode - returning mock handle")
            return RecordingHandle(segmentID: UUID())
        }
        
        // 1. Check permissions
        #if os(iOS)
        log("Checking microphone permission...")
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
        log("Microphone permission: \(granted)")
        guard granted else {
            log("Permission denied", level: "ERROR")
            throw RecorderError.permissionDenied
        }
        #endif
        
        // 2. Configure audio session
        log("Configuring AVAudioSession for continuous recording...")
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            log("AVAudioSession configured successfully")
        } catch {
            log("Failed to configure AVAudioSession: \(error)", level: "ERROR")
            throw RecorderError.underlying(error)
        }
        
        // 3. Generate file URL
        let fileID = UUID().uuidString
        let url = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("continuous_\(fileID)")
            .appendingPathExtension("m4a")
        log("Generated continuous file URL: \(url.lastPathComponent)")
        
        // 4. Create recorder with optimized settings
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        log("Audio settings: format=AAC, sampleRate=44.1kHz, channels=1, quality=high")
        
        do {
            let newRecorder = try AVAudioRecorder(url: url, settings: settings)
            // Enable metering for potential waveform visualization
            newRecorder.isMeteringEnabled = true
            let started = newRecorder.record()
            
            recorder = newRecorder
            currentURL = url
            recordingStartTime = Date()
            dreamID = UUID()
            
            log("Continuous recording started: \(started), dreamID: \(dreamID!)")
            
            // Start checkpoint timer for recordings > 30s
            scheduleCheckpointTask()
            
        } catch {
            log("Failed to start recording: \(error)", level: "ERROR")
            throw RecorderError.underlying(error)
        }
        
        let handle = RecordingHandle(segmentID: UUID())
        log("Returning handle with segmentID: \(handle.segmentID)")
        return handle
    }
    
    public func stop(_ handle: RecordingHandle) async throws -> CompletedSegment {
        log("stop() called with handle: \(handle.segmentID)")
        
        // For preview/testing
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            log("Preview mode - returning mock segment")
            return CompletedSegment(segmentID: handle.segmentID,
                                    filename: "\(UUID()).m4a",
                                    duration: 0)
        }
        
        guard let r = recorder, let url = currentURL else {
            log("No active session", level: "ERROR")
            throw RecorderError.noActiveSession
        }
        
        // Stop recording
        let duration = r.currentTime
        r.stop()
        
        // Cancel checkpoint task
        checkpointTask?.cancel()
        checkpointTask = nil
        
        // Calculate actual duration
        let actualDuration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? duration
        log("Recording stopped - AVRecorder duration: \(duration)s, actual: \(actualDuration)s")
        
        // For short recordings (<30s), behave exactly like the original
        if actualDuration < checkpointInterval {
            log("Short recording (<30s) - using simple path")
            
            // Move to library
            let dreamsRoot = FileManager.default
                .urls(for: .libraryDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Dreams", isDirectory: true)
            
            log("Creating Dreams directory if needed...")
            try? FileManager.default.createDirectory(at: dreamsRoot,
                                                     withIntermediateDirectories: true)
            
            let permanentURL = dreamsRoot.appendingPathComponent(url.lastPathComponent)
            log("Moving file from cache to library: \(url.lastPathComponent)")
            
            do {
                try FileManager.default.moveItem(at: url, to: permanentURL)
                log("File moved successfully to: \(permanentURL.path)")
            } catch {
                log("Failed to move file: \(error)", level: "ERROR")
                throw RecorderError.underlying(error)
            }
            
            // Clean up state
            recorder = nil
            currentURL = nil
            recordingStartTime = nil
            dreamID = nil
            currentCheckpoint = nil
            
            let segment = CompletedSegment(segmentID: handle.segmentID,
                                           filename: permanentURL.lastPathComponent,
                                           duration: duration)
            log("Returning completed segment: \(segment.filename), duration: \(segment.duration)s")
            return segment
            
        } else {
            // Long recording (≥30s) - checkpoint system was active
            log("Long recording (≥30s) - checkpoint system was active")
            log("Total checkpoints saved: \(currentCheckpoint?.checkpointCount ?? 0)")
            
            // Move to library with checkpoint metadata
            let dreamsRoot = FileManager.default
                .urls(for: .libraryDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Dreams", isDirectory: true)
            
            try? FileManager.default.createDirectory(at: dreamsRoot,
                                                     withIntermediateDirectories: true)
            
            let permanentURL = dreamsRoot.appendingPathComponent(url.lastPathComponent)
            
            do {
                try FileManager.default.moveItem(at: url, to: permanentURL)
                log("Long recording file moved successfully")
                
                // Save final checkpoint metadata
                if let checkpoint = currentCheckpoint {
                    let metadataURL = permanentURL.deletingPathExtension().appendingPathExtension("checkpoint")
                    let finalCheckpoint = RecordingCheckpoint(
                        dreamID: checkpoint.dreamID,
                        startTime: checkpoint.startTime,
                        lastCheckpoint: Date(),
                        checkpointCount: checkpoint.checkpointCount,
                        fileURL: permanentURL
                    )
                    let encoder = JSONEncoder()
                    if let data = try? encoder.encode(finalCheckpoint) {
                        try? data.write(to: metadataURL)
                        log("Final checkpoint metadata saved")
                    }
                }
            } catch {
                log("Failed to move file: \(error)", level: "ERROR")
                throw RecorderError.underlying(error)
            }
            
            // Clean up state
            recorder = nil
            currentURL = nil
            recordingStartTime = nil
            dreamID = nil
            currentCheckpoint = nil
            
            let segment = CompletedSegment(segmentID: handle.segmentID,
                                           filename: permanentURL.lastPathComponent,
                                           duration: duration)
            log("Returning completed long recording segment: duration: \(segment.duration)s")
            return segment
        }
    }
    
    // MARK: - Checkpoint System
    
    private func scheduleCheckpointTask() {
        log("Scheduling checkpoint task (30s interval)")
        checkpointTask = Task {
            // Wait for first checkpoint interval
            try? await Task.sleep(nanoseconds: UInt64(checkpointInterval * 1_000_000_000))
            
            // Continue saving checkpoints while not cancelled
            while !Task.isCancelled {
                await saveCheckpoint()
                try? await Task.sleep(nanoseconds: UInt64(checkpointInterval * 1_000_000_000))
            }
        }
    }
    
    private func saveCheckpoint() async {
        guard let startTime = recordingStartTime,
              let dreamID = dreamID,
              let url = currentURL else {
            log("Cannot save checkpoint - missing required state", level: "WARN")
            return
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        log("Saving checkpoint at \(String(format: "%.1f", elapsed))s")
        
        // Create or update checkpoint
        let checkpointCount = (currentCheckpoint?.checkpointCount ?? 0) + 1
        let checkpoint = RecordingCheckpoint(
            dreamID: dreamID,
            startTime: startTime,
            lastCheckpoint: Date(),
            checkpointCount: checkpointCount,
            fileURL: url
        )
        
        // Save checkpoint metadata
        let checkpointURL = url.deletingPathExtension().appendingPathExtension("checkpoint")
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(checkpoint)
            try data.write(to: checkpointURL)
            currentCheckpoint = checkpoint
            log("Checkpoint #\(checkpointCount) saved successfully")
        } catch {
            log("Failed to save checkpoint: \(error)", level: "ERROR")
        }
    }
}

#endif