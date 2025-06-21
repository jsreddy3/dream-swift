#if DEBUG
// 2.  Let tests peek at the pending queue so we can assert it drains.
extension SyncingDreamStore {
    
    nonisolated func test_setOnline(_ online: Bool) async {
        await networkChanged(online)          // same code path the NWPathMonitor uses
    }
    
    /// Current length of the offline queue.
    func test_pendingCount() async -> Int {
        queue.count                           // actor-isolated access is OK here
    }
}
#endif
