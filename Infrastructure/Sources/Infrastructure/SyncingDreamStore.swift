//
//  SyncingDreamStore.swift
//  Infrastructure
//
//  Unified audio/text implementation
//

import Foundation
import Network
import DomainLogic
import CoreModels

public actor SyncingDreamStore: DreamStore, Sendable {

    // MARK: – Dependencies
    private let local: FileDreamStore
    private let remote: RemoteDreamStore

    // MARK: – Durable queue
    internal var queue: [PendingOp]
    private let queueURL: URL

    // MARK: – Reachability
    private let monitor = NWPathMonitor()
    private var isOnline = false

    // MARK: – Live uploads passthrough
    private let uploadsStream: AsyncStream<UploadResult>
    private let uploadsCont: AsyncStream<UploadResult>.Continuation
    public var uploads: AsyncStream<UploadResult> { uploadsStream }

    // MARK: – Init
    public init(local: FileDreamStore, remote: RemoteDreamStore) {
        self.local  = local
        self.remote = remote

        let lib = FileManager.default.urls(for: .libraryDirectory,
                                           in: .userDomainMask)[0]
        self.queueURL = lib.appendingPathComponent("DreamsSyncQueue.json")

        // 1. Load the pending queue from disk before actor isolation
        self.queue = Self.initialQueue(from: queueURL)

        // 2. Live-upload relay
        var c: AsyncStream<UploadResult>.Continuation!
        let stream = AsyncStream<UploadResult> { cont in c = cont }
        uploadsStream = stream
        uploadsCont   = c

        let relayTask = Task.detached { [weak self] in
            guard let self else { return }
            for await result in await self.remote.uploads {
                if !result.transcript.isEmpty {
                    try? await self.mergeTranscript(result)
                }
                self.uploadsCont.yield(result)
            }
        }
        c.onTermination = { _ in relayTask.cancel() }

        // 3. Reachability watcher
        monitor.pathUpdateHandler = { [weak self] path in
            Task { await self?.networkChanged(path.status == .satisfied) }
        }
        monitor.start(queue: .global(qos: .utility))
    }

    // MARK: – DreamStore writes (write-through + queue)

    public func insertNew(_ dream: Dream) async throws {
        try await local.insertNew(dream)
        enqueue(.create(dream))
    }

    public func appendSegment(dreamID: UUID, segment: Segment) async throws {
        try await local.appendSegment(dreamID: dreamID, segment: segment)
        enqueue(.append(dreamID: dreamID, segment: segment))
    }

    public func removeSegment(dreamID: UUID, segmentID: UUID) async throws {
        do { try await local.removeSegment(dreamID: dreamID, segmentID: segmentID) }
        catch {
            NSLog("mergeTranscript: remove failed with \(error)")
            assertionFailure("removeSegment failed: \(error)")
        }
        enqueue(.remove(dreamID: dreamID, segmentID: segmentID))
    }

    public func markCompleted(_ id: UUID) async throws -> Dream {
        // Mark completed locally first
        let localDream = try await local.markCompleted(id)
        enqueue(.finish(id))
        
        // If online, ensure all pending operations for this dream are synced first
        if isOnline {
            // Process any pending operations for this dream before marking complete
            await drainOperationsForDream(id)
            
            do {
                return try await remote.markCompleted(id)
            } catch {
                // If remote fails, return local dream
                return localDream
            }
        }
        return localDream
    }

    public func updateTitle(dreamID: UUID, title: String) async throws {
        try await local.updateTitle(dreamID: dreamID, title: title)
        enqueue(.rename(dreamID: dreamID, title: title))
    }

    public func updateSummary(dreamID: UUID, summary: String) async throws {
        try await local.updateSummary(dreamID: dreamID, summary: summary)
        enqueue(.updateSummary(dreamID: dreamID, summary: summary))
    }

    public func updateTitleAndSummary(dreamID: UUID, title: String, summary: String) async throws {
        try await local.updateTitleAndSummary(dreamID: dreamID, title: title, summary: summary)
        enqueue(.updateTitleAndSummary(dreamID: dreamID, title: title, summary: summary))
    }
    
    public func deleteDream(_ id: UUID) async throws {
        try await local.deleteDream(id)
        if isOnline {
            try await remote.deleteDream(id)
        } else {
            enqueue(.delete(id))
        }
    }

    // MARK: – DreamStore reads (cache first, reconcile in background)

    public func segments(dreamID id: UUID) async throws -> [Segment] {
        let cached = try await local.segments(dreamID: id)          // fast path

        if isOnline {
            Task.detached { [weak self] in
                guard let self else { return }
                if let remote = try? await self.remote.segments(dreamID: id),
                   remote.count >= cached.count,
                   remote != cached {
                    try? await self.local.replaceSegments(id, with: remote)
                }
            }
        }
        return cached
    }

    public func allDreams() async throws -> [Dream] {
        let cached = try await local.allDreams()

        if isOnline {
            // Add timeout protection to prevent hanging during startup
            do {
                let cloud = try await withTimeout(seconds: 8.0) { [self] in
                    try await remote.allDreams()
                }
                for dream in cloud {
                    try? await local.upsert(dream)
                }
                return cloud.sorted { $0.created_at > $1.created_at }
            } catch {
                // If remote call fails (including timeout), fall back to cached data
                #if DEBUG
                print("SyncingDreamStore: Remote allDreams failed, using cached data: \(error)")
                #endif
                return cached.sorted { $0.created_at > $1.created_at }
            }
        }
        return cached.sorted { $0.created_at > $1.created_at }
    }

    public func getTranscript(dreamID id: UUID) async throws -> String? {
        let cached = try await local.getTranscript(dreamID: id)

        if isOnline {
            Task.detached { [weak self] in
                guard let self else { return }
                if let remote = try? await self.remote.getTranscript(dreamID: id),
                   remote != cached {
                    try? await self.local.updateDream(id) { $0.transcript = remote }
                }
            }
        }
        return cached
    }
    
    public func getDream(_ id: UUID) async throws -> Dream {
        // 1️⃣ try fast local hit
        if let cached = try? await local.getDream(id) {
            // 2️⃣ kick off remote refresh in background (if online)
            if isOnline {
                Task.detached { [weak self] in
                    guard let self else { return }
                    if let fresh = try? await self.remote.getDream(id) {
                        try? await self.local.upsert(fresh)
                    }
                }
            }
            return cached
        }

        // 3️⃣ no cache → fetch remote (may still throw offline)
        let fresh = try await remote.getDream(id)
        try? await local.upsert(fresh)
        return fresh
    }

    public func requestAnalysis(for id: UUID) async throws {
        #if DEBUG
        print("DEBUG: SyncingDreamStore.requestAnalysis called, isOnline: \(isOnline)")
        #endif
        // delegate straight to remote if we're online,
        // otherwise enqueue for later just like other ops.
        if isOnline {
            #if DEBUG
            print("DEBUG: Calling remote.requestAnalysis with timeout protection")
            #endif
            try await withTimeout(seconds: 15.0) { [self] in
                try await remote.requestAnalysis(for: id)
            }
        } else {
            #if DEBUG
            print("DEBUG: Offline, enqueueing for later")
            #endif
            enqueue(.analyze(id))   // ← you may add this PendingOp later
        }
    }
    
    public func requestExpandedAnalysis(for id: UUID) async throws {
        #if DEBUG
        print("DEBUG: SyncingDreamStore.requestExpandedAnalysis called, isOnline: \(isOnline)")
        #endif
        if isOnline {
            #if DEBUG
            print("DEBUG: Calling remote.requestExpandedAnalysis with timeout protection")
            #endif
            try await withTimeout(seconds: 15.0) { [self] in
                try await remote.requestExpandedAnalysis(for: id)
            }
        } else {
            #if DEBUG
            print("DEBUG: Offline, can't do expanded analysis")
            #endif
        }
    }

    public func getVideoURL(dreamID: UUID) async throws -> URL? {
        isOnline ? try await remote.getVideoURL(dreamID: dreamID) : nil
    }

    // MARK: – Queue draining

    public func drain() async {
        guard isOnline else { return }
        while isOnline, !queue.isEmpty {
            let op = queue.removeFirst()
            do {
                try await perform(op)
                truncateLogIfEmpty()
            } catch {
                queue.insert(op, at: 0)
                break
            }
        }
    }
    
    // Drain operations for a specific dream
    private func drainOperationsForDream(_ dreamId: UUID) async {
        guard isOnline else { return }
        
        // Find and process all operations related to this dream
        var remainingOps: [PendingOp] = []
        var opsToProcess: [PendingOp] = []
        
        // Separate operations for this dream from others
        for op in queue {
            if isDreamRelatedOperation(op, dreamId: dreamId) {
                opsToProcess.append(op)
            } else {
                remainingOps.append(op)
            }
        }
        
        // Update queue to only contain non-dream operations
        queue = remainingOps
        
        // Process all operations for this dream
        for op in opsToProcess {
            do {
                try await perform(op)
            } catch {
                // If an operation fails, put it back at the front of the queue
                queue.insert(op, at: 0)
                break
            }
        }
        
        // Update the persistent log
        truncateLogIfEmpty()
    }
    
    // Helper to check if an operation is related to a specific dream
    private func isDreamRelatedOperation(_ op: PendingOp, dreamId: UUID) -> Bool {
        switch op {
        case .create(let dream):
            return dream.id == dreamId
        case .append(let id, _), .remove(let id, _), .rename(let id, _), 
             .updateSummary(let id, _), .updateTitleAndSummary(let id, _, _),
             .finish(let id), .analyze(let id), .delete(let id):
            return id == dreamId
        }
    }
    
    public func generateSummary(for id: UUID) async throws -> String {
        if isOnline {
            let summary = try await remote.generateSummary(for: id)
            // IMPORTANT: After generating summary, the backend also updates the title
            // We need to fetch the complete updated dream to get both title and summary
            if let fresh = try? await remote.getDream(id) {
                try? await local.upsert(fresh)
            }
            return summary
        }
        
        // Offline – produce fallback exactly like FileDreamStore
        return try await local.generateSummary(for: id)
    }

    // MARK: – Queue helpers

    private func enqueue(_ op: PendingOp) {
        queue.append(op)
        appendToLog(op)
        if isOnline { Task { await drain() } }
    }

    private func appendToLog(_ op: PendingOp) {
        guard let line = try? JSONEncoder().encode(op) else { return }
        var handle: FileHandle? = try? FileHandle(forUpdating: queueURL)

        if handle == nil {
            FileManager.default.createFile(atPath: queueURL.path, contents: nil)
            handle = try? FileHandle(forUpdating: queueURL)
        }
        guard let h = handle else { return }
        try? h.seekToEnd()
        try? h.write(contentsOf: line + Data([0x0A]))
        try? h.close()
    }

    private func truncateLogIfEmpty() {
        if queue.isEmpty {
            try? Data().write(to: queueURL, options: .atomic)
        }
    }

    private static func initialQueue(from url: URL) -> [PendingOp] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return data.split(separator: 0x0A).compactMap {
            try? JSONDecoder().decode(PendingOp.self, from: $0)
        }
    }

    // MARK: – Reachability callback

    internal func networkChanged(_ now: Bool) async {
        isOnline = now
        if isOnline { await drain() }
    }

    // MARK: – Remote operation dispatcher

    private func perform(_ op: PendingOp) async throws {
        switch op {
        case .create(let d):             
            try await remote.insertNew(d)
        case .append(let id, let s):     
            try await remote.appendSegment(dreamID: id, segment: s)
        case .remove(let id, let sid):   
            try await remote.removeSegment(dreamID: id, segmentID: sid)
        case .rename(let id, let t):     
            try await remote.updateTitle(dreamID: id, title: t)
        case .updateSummary(let id, let s): 
            try await remote.updateSummary(dreamID: id, summary: s)
        case .updateTitleAndSummary(let id, let t, let s): 
            try await remote.updateTitleAndSummary(dreamID: id, title: t, summary: s)
        case .finish(let id):
            do {
                try await remote.markCompleted(id)
            } catch {
                // If dream doesn't exist (404), don't retry this operation
                if let remoteError = error as? RemoteError,
                   case .badStatus(let code, _) = remoteError,
                   code == 404 {
                    #if DEBUG
                    print("Dream \(id) not found on server, skipping finish operation")
                    #endif
                    return
                }
                throw error
            }
        case .analyze(let id):           
            try await remote.requestAnalysis(for: id)
        case .delete(let id):            
            try await remote.deleteDream(id)
        }
    }

    // MARK: – Timeout Helper
    
    private func withTimeout<T: Sendable>(seconds: Double, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            // Add the actual operation
            group.addTask {
                try await operation()
            }
            
            // Add a timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw SyncingDreamStoreError.timeout
            }
            
            // Return the first result (either success or timeout)
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    // MARK: – Transcript merge (immutable Segment copy)

    private func mergeTranscript(_ r: UploadResult) async throws {
        let list = try await local.segments(dreamID: r.dreamID)
        guard let idx = list.firstIndex(where: { $0.id == r.segmentID }) else { return }

        let old = list[idx]

        // Text clips never receive late transcripts.
        guard old.modality == SegmentModality.audio else { return }

        let updated = Segment(id: old.id,
                              modality: .audio,
                              order: old.order,
                              filename: old.filename,
                              duration: old.duration,
                              text: old.text,
                              transcript: r.transcript)

        try await local.removeSegment(dreamID: r.dreamID, segmentID: r.segmentID)
        try await local.upsertSegment(updated, dreamID: r.dreamID)
    }
}

// MARK: – Codable op descriptions (persisted queue)

internal enum PendingOp: Codable {
    case create(Dream)
    case append(dreamID: UUID, segment: Segment)
    case remove(dreamID: UUID, segmentID: UUID)
    case rename(dreamID: UUID, title: String)
    case updateSummary(dreamID: UUID, summary: String)
    case updateTitleAndSummary(dreamID: UUID, title: String, summary: String)
    case finish(UUID)
    case analyze(UUID)
    case delete(UUID)
}

enum SyncingDreamStoreError: Error {
    case timeout
}
