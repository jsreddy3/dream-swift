//
//  SyncingDreamStore.swift
//  Infrastructure
//
//  Fixed version – avoids actor-init isolation error
//                – handles let transcript field immutably
//

import Foundation
import Network
import DomainLogic
import CoreModels

public actor SyncingDreamStore: DreamStore, Sendable {

    // MARK: Dependencies
    private let local: FileDreamStore
    private let remote: RemoteDreamStore

    // MARK: Durable queue
    private var queue: [PendingOp]
    private let queueURL: URL

    // MARK: Reachability
    private let monitor = NWPathMonitor()
    private var isOnline = false

    // MARK: Live uploads passthrough
    private let uploadsStream: AsyncStream<UploadResult>
    private let uploadsCont: AsyncStream<UploadResult>.Continuation
    public var uploads: AsyncStream<UploadResult> { uploadsStream }

    // MARK: Init
    public init(local: FileDreamStore, remote: RemoteDreamStore) {
        self.local  = local
        self.remote = remote

        let lib = FileManager.default.urls(for: .libraryDirectory,
                                           in: .userDomainMask)[0]
        self.queueURL = lib.appendingPathComponent("DreamsSyncQueue.json")

        // -------- 1. load queue before actor isolation matters --------
        self.queue = Self.initialQueue(from: queueURL)

        // -------- 2. live-upload relay --------
        var c: AsyncStream<UploadResult>.Continuation!
        let stream = AsyncStream<UploadResult> { cont in
            c = cont
        }
        uploadsStream = stream
        uploadsCont   = c

        // launch the forwarding task and store it in an immutable binding
        let relayTask = Task.detached { [weak self] in
            guard let self else { return }
            for await result in await self.remote.uploads {
                if !result.transcript.isEmpty {
                    try? await self.mergeTranscript(result)
                }
                self.uploadsCont.yield(result)
            }
        }

        // now that the task exists, hook it to the stream’s lifetime
        c.onTermination = { _ in relayTask.cancel() }

        // -------- 3. reachability watcher --------
        monitor.pathUpdateHandler = { [weak self] path in
            Task { await self?.networkChanged(path.status == .satisfied) }
        }
        monitor.start(queue: .global(qos: .utility))
    }

    // MARK: DreamStore writes (write-through + queue)
    public func insertNew(_ dream: Dream) async throws {
        try await local.insertNew(dream)
        enqueue(.create(dream))
    }
    public func appendSegment(dreamID: UUID, segment: AudioSegment) async throws {
        try await local.appendSegment(dreamID: dreamID, segment: segment)
        enqueue(.append(dreamID: dreamID, segment: segment))
    }
    public func removeSegment(dreamID: UUID, segmentID: UUID) async throws {
        try await local.removeSegment(dreamID: dreamID, segmentID: segmentID)
        enqueue(.remove(dreamID: dreamID, segmentID: segmentID))
    }
    public func markCompleted(_ id: UUID) async throws {
        try await local.markCompleted(id)
        enqueue(.finish(id))
    }
    public func updateTitle(dreamID: UUID, title: String) async throws {
        try await local.updateTitle(dreamID: dreamID, title: title)
        enqueue(.rename(dreamID: dreamID, title: title))
    }
    // MARK: DreamStore reads – cached first, reconcile in background
    public func segments(dreamID id: UUID) async throws -> [AudioSegment] {
        let cached = try await local.segments(dreamID: id)          // fast path

        if isOnline {                                               // don’t wake radios if down
            Task.detached { [weak self] in
                guard let self else { return }
                if let remote = try? await self.remote.segments(dreamID: id),
                   remote.count >= cached.count,      // ← this guard is critical
                   remote != cached
                {
                    try? await self.local.replaceSegments(id, with: remote)
                }
            }
        }
        return cached
    }

    public func allDreams() async throws -> [Dream] {
        let cached = try await local.allDreams()

        if isOnline {
            Task.detached { [weak self] in
                guard let self else { return }
                if let cloud = try? await self.remote.allDreams(),
                   cloud != cached {
                    for dream in cloud { try? await self.local.upsert(dream) }
                }
            }
        }
        return cached
    }

    public func getTranscript(dreamID id: UUID) async throws -> String? {
        let cached = try await local.getTranscript(dreamID: id)     // may be nil / empty

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


    // MARK: Queue helpers
    private func enqueue(_ op: PendingOp) {
        queue.append(op)
        appendToLog(op)                       // ← replaces persistQueue()
        if isOnline { Task { await drain() } }
    }
    
    private func appendToLog(_ op: PendingOp) {
        guard let line = try? JSONEncoder().encode(op) else { return }
        var handle: FileHandle? = try? FileHandle(forUpdating: queueURL)

        if handle == nil {            // first write ever
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
            try? Data().write(to: queueURL, options: .atomic)   // zero-length file
        }
    }
    
    private static func initialQueue(from url: URL) -> [PendingOp] {
        guard let data = try? Data(contentsOf: url) else { return [] }

        var ops: [PendingOp] = []
        for slice in data.split(separator: 0x0A) {             // 0x0A == '\n'
            if let op = try? JSONDecoder().decode(PendingOp.self, from: slice) {
                ops.append(op)
            }
        }
        return ops
    }

    // MARK: Draining
    private func networkChanged(_ now: Bool) async {
        isOnline = now
        if isOnline { await drain() }
    }
    
    private func drain() async {
        guard isOnline else { return }

        while isOnline, !queue.isEmpty {
            let op = queue.removeFirst()      // remove from RAM
            do {
                try await perform(op)
                truncateLogIfEmpty()          // ← compact only when queue is empty
            } catch {
                queue.insert(op, at: 0)       // push back
                break                         // bail; retry later
            }
        }
    }
    
    private func perform(_ op: PendingOp) async throws {
        switch op {
        case .create(let d):             try await remote.insertNew(d)
        case .append(let id, let s):     try await remote.appendSegment(dreamID: id, segment: s)
        case .remove(let id, let sid):   try await remote.removeSegment(dreamID: id, segmentID: sid)
        case .rename(let id, let t):     try await remote.updateTitle(dreamID: id, title: t)
        case .finish(let id):            try await remote.markCompleted(id)
        }
    }

    // MARK: Transcript merge (immutable AudioSegment)
    private func mergeTranscript(_ r: UploadResult) async throws {
        let list = try await local.segments(dreamID: r.dreamID)
        guard let idx = list.firstIndex(where: { $0.id == r.segmentID }) else { return }

        let old = list[idx]
        let updated = AudioSegment(id: old.id,
                                   filename: old.filename,
                                   duration: old.duration,
                                   order: old.order,
                                   transcript: r.transcript)

        // Rewrite: drop old, add new (preserves order property)
        try await local.removeSegment(dreamID: r.dreamID, segmentID: r.segmentID)
        try await local.appendSegment(dreamID: r.dreamID, segment: updated)
    }
}

// MARK: Codable op descriptions
private enum PendingOp: Codable {
    case create(Dream)
    case append(dreamID: UUID, segment: AudioSegment)
    case remove(dreamID: UUID, segmentID: UUID)
    case rename(dreamID: UUID, title: String)
    case finish(UUID)
}
