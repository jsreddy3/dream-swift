//
//  GetTranscript.swift           (DomainLogic)
//  Created by DreamFinder.
//

import Foundation
import CoreModels            // for Dream, DreamState
                                // (and whatever error enum you prefer)

/// Returns the full, merged transcript for a dream
/// once that dream is in the `.completed` state.
///
/// Throws:
/// – `DomainError.dreamIsNotFinished` if the caller asks
///   for a draft dream.
/// – `DomainError.transcriptUnavailable` if the backend
///   replied with an empty or nil transcript.
public struct GetTranscript: Sendable {

    private let store: DreamStore          // protocol, injected

    public init(store: DreamStore) {
        self.store = store
    }

    public func callAsFunction(id: UUID) async throws -> String {
        let raw = try await store.getTranscript(dreamID: id)

        // 3. Return the canonical, trimmed string.
        return raw?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ) ?? ""
    }
}
