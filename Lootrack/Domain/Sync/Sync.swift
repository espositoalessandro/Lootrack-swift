import Foundation
import SwiftData

@MainActor
@Observable
final class Sync {

    private let context: ModelContext

    init(modelContext: ModelContext) {
        self.context = modelContext
    }

    func createMutation<T: Entity>(
        _ entity: T,
        _ operation: SyncOperation,
        _ changes: [MutationChange]
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
                entityId: entity.id,
                lastMutationId: mutation.id,
                revision: 1
            )
            context.insert(newState)
        }

        context.insert(mutation)
    }

    private func mutationFrom<T: Entity>(
        _ entity: T,
        _ operation: SyncOperation,
        _ changes: [MutationChange]
    ) -> Mutation {

        let mutationId = UUID()
        let entityRef: EntityRef

        switch entity {
        case let transaction as Transaction:
            entityRef = .transaction(transaction)

        case let category as Category:
            entityRef = .category(category)

        default:
            fatalError("Unsupported entity type: \(type(of: entity))")
        }

        return .init(
            id: mutationId,
            entity: entityRef,
            operation: operation,
            changes: changes
        )
    }

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        return try JSONEncoder().encode(value)
    }

}
