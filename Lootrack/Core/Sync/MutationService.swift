import Foundation
import SwiftData

@MainActor
@Observable
final class MutationService {

    private let context: ModelContext

    init(modelContext: ModelContext) {
        self.context = modelContext
    }

    func createMutation<T: Identifiable>(
        from old: T,
        to new: T,
        _ operation: SyncOperation,
    ) throws {
        
        let mutation = mutationFrom(entity, operation, changes)

        let state = try context.fetch(
            MutationQueries.getEntitySyncState(entity.id)
        ).first

        if state != nil {
            mutation.expectedMutationId = state!.lastMutationId
            mutation.expectedRevision = state!.revision

            state!.revision += 1
            state!.lastMutationId = mutation.id

        } else {
            let newState = EntitySyncState(
                entityId: new.id,
                lastMutationId: mutation.id,
                revision: 1
            )
            context.insert(newState)
        }

        context.insert(mutation)
    }

    private func mutationFrom(
        from old: EntitySnapshot,
        to new: EntitySnapshot,
        _ operation: SyncOperation,
    ) -> Mutation {

        let mutationId = UUID()
        let entityRef: EntityRef

        return .init(
            id: mutationId,
            from: old,
            to: new,
            operation: operation,
        )
    }

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        return try JSONEncoder().encode(value)
    }

}
