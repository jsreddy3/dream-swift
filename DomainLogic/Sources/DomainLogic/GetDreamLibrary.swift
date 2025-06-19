import CoreModels

public struct GetDreamLibrary: Sendable {
    private let store: DreamStore
    public init(store: DreamStore) { self.store = store }
    public func callAsFunction() async throws -> [Dream] { try await store.allDreams() }
}
