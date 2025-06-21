import XCTest
@testable import Infrastructure
@testable import DomainLogic
import CoreModels
import Foundation

// MARK: – helpers ------------------------------------------------------------

private func clearSyncLog() {
    let lib = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
    try? FileManager.default.removeItem(at: lib.appendingPathComponent("DreamsSyncQueue.json"))
}

private func tmpDir() -> URL {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

private func makeDream(title: String = "d") -> Dream {
    Dream(id: .init(),
          created: .now,
          title: title,
          transcript: nil,
          segments: [],
          state: .draft)
}

// MARK: – URLProtocol fixtures ----------------------------------------------

final class DummyProtocol: URLProtocol {
    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for r: URLRequest) -> URLRequest { r }
    override func startLoading() {
        let resp = HTTPURLResponse(url: request.url!, statusCode: 200,
                                   httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private func makeRemoteAlwaysOK() -> RemoteDreamStore {
    let cfg = URLSessionConfiguration.ephemeral
    cfg.protocolClasses = [DummyProtocol.self]
    return RemoteDreamStore(baseURL: URL(string: "https://x.invalid")!,
                            session: URLSession(configuration: cfg))
}

final class NullProtocol: URLProtocol {
    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for r: URLRequest) -> URLRequest { r }
    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: URLError(.cancelled))
    }
    override func stopLoading() {}
}

private func makeNullRemote() -> RemoteDreamStore {
    let cfg = URLSessionConfiguration.ephemeral
    cfg.protocolClasses = [NullProtocol.self]
    return RemoteDreamStore(baseURL: URL(string: "https://x.invalid")!,
                            session: URLSession(configuration: cfg))
}

// ---------------------------------------------------------------------------
// Sync-queue drains once online ---------------------------------------------

final class SyncingDreamStoreTests: XCTestCase {

    func testQueueDrainsWhenNetworkReturns() async throws {
        clearSyncLog()

        let sync = SyncingDreamStore(
            local: FileDreamStore(customRootURL: tmpDir()),
            remote: makeRemoteAlwaysOK())

        await sync.test_setOnline(false)          // start offline
        try await sync.insertNew(makeDream())     // enqueue 1 op

        await sync.test_setOnline(true)           // bring network back
        try await Task.sleep(nanoseconds: 200_000_000)

        let pending = await sync.test_pendingCount()
        XCTAssertEqual(pending, 0)
    }
}

// ---------------------------------------------------------------------------
// Queue is re-hydrated across process restarts ------------------------------

final class RehydrateQueueTests: XCTestCase {

    func testQueuePersistsAcrossStoreRebuild() async throws {
            clearSyncLog()
            let dir = tmpDir()

            // ── first launch ────────────────────────────────────────────────
            var store: SyncingDreamStore? = SyncingDreamStore(
                local: FileDreamStore(customRootURL: dir),
                remote: makeNullRemote())          // always fails → never drains

            await store!.test_setOnline(false)     // force offline
            try await store!.insertNew(makeDream())
            try await Task.sleep(nanoseconds: 100_000_000)     // let background tasks finish

            let before = await store!.test_pendingCount()
            XCTAssertGreaterThan(before, 0)        // at least one op queued

            store = nil                            // simulate terminate

            // ── second launch ───────────────────────────────────────────────
            let revived = SyncingDreamStore(
                local: FileDreamStore(customRootURL: dir),
                remote: makeNullRemote())

            let after = await revived.test_pendingCount()
            XCTAssertEqual(after, before)          // exact same count survived
        }
}

// ---------------------------------------------------------------------------
// Retry logic: failed op stays queued, then succeeds ------------------------

final class FlakyProtocol: URLProtocol {
    private nonisolated(unsafe) static var first = true

    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for r: URLRequest) -> URLRequest { r }

    override func startLoading() {
        let code: Int
        if Self.first { code = 500; Self.first = false } else { code = 200 }
        let resp = HTTPURLResponse(url: request.url!, statusCode: code,
                                   httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private func makeFlakyRemote() -> RemoteDreamStore {
    let cfg = URLSessionConfiguration.ephemeral
    cfg.protocolClasses = [FlakyProtocol.self]
    return RemoteDreamStore(baseURL: URL(string: "https://x.invalid")!,
                            session: URLSession(configuration: cfg))
}

final class RetryDrainTests: XCTestCase {

    func testOpRequeuedAfterFailureThenSucceeds() async throws {
        clearSyncLog()

        let sync = SyncingDreamStore(
            local: FileDreamStore(customRootURL: tmpDir()),
            remote: makeFlakyRemote())

        await sync.test_setOnline(false)
        try await sync.insertNew(makeDream())
        let queued = await sync.test_pendingCount()
        XCTAssertEqual(queued, 1)

        // first pass: server 500 → op remains
        await sync.test_setOnline(true)
        try await Task.sleep(nanoseconds: 200_000_000)
        let stillQueued = await sync.test_pendingCount()
        XCTAssertEqual(stillQueued, 1)

        // second pass: server 200 → drains
        await sync.test_setOnline(true)
        try await Task.sleep(nanoseconds: 200_000_000)
        let drained = await sync.test_pendingCount()
        XCTAssertEqual(drained, 0)
    }
}

// ---------------------------------------------------------------------------
// FIFO order is preserved ----------------------------------------------------

final class RecorderProtocol: URLProtocol {
    nonisolated(unsafe) static var paths: [String] = []

    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for r: URLRequest) -> URLRequest { r }

    override func startLoading() {
        Self.paths.append(request.url!.path)
        let resp = HTTPURLResponse(url: request.url!, statusCode: 200,
                                   httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private func makeRecordingRemote() -> RemoteDreamStore {
    RecorderProtocol.paths = []
    let cfg = URLSessionConfiguration.ephemeral
    cfg.protocolClasses = [RecorderProtocol.self]
    return RemoteDreamStore(baseURL: URL(string: "https://x.invalid")!,
                            session: URLSession(configuration: cfg))
}

final class FIFOOrderTests: XCTestCase {

    func testReplayHappensInEnqueueOrder() async throws {
        clearSyncLog()

        let sync = SyncingDreamStore(
            local: FileDreamStore(customRootURL: tmpDir()),
            remote: makeRecordingRemote())

        await sync.test_setOnline(false)
        try await sync.insertNew(makeDream(title: "first"))
        try await sync.insertNew(makeDream(title: "second"))

        await sync.test_setOnline(true)
        try await Task.sleep(nanoseconds: 200_000_000)

        let suffixes = Array(RecorderProtocol.paths.suffix(2))
        XCTAssertEqual(suffixes, ["/dreams", "/dreams"])   // <- no trailing slash
    }
}

// ---------------------------------------------------------------------------
// DEBUG-only hooks into the actor (same as before) ---------------------------

#if DEBUG
extension SyncingDreamStore {
    nonisolated func test_setOnline(_ online: Bool) async { await networkChanged(online) }
    func test_pendingCount() async -> Int { queue.count }
}
#endif
