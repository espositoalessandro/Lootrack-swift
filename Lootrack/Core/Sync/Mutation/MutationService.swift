import Foundation
import SwiftData

nonisolated enum MutationServiceError: Error {
    case snapshotIdentityMismatch
}

@MainActor
final class MutationService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func createMutation(from old: EntitySnapshot?,
                        to new: EntitySnapshot,
                        _ operation: SyncOperation) throws
    {
        if let old, old.key != new.key {
            throw MutationServiceError.snapshotIdentityMismatch
        }

        if let old, old == new {
            return
        }

        let mutation = Mutation(from: old,
                                to: new,
                                operation: operation)

        let state = try modelContext.fetch(MutationQueries.getEntitySyncState(new.key)).first

        if let state {
            mutation.expectedMutationId = state.lastMutationId
            mutation.expectedRevision = state.revision

            state.revision += 1
            state.lastMutationId = mutation.id
        } else {
            let newState = EntitySyncState(key: new.key,
                                           lastMutationId: mutation.id,
                                           revision: 1)

            modelContext.insert(newState)
        }

        modelContext.insert(mutation)
    }
}
