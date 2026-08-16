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
        _ changes: String?
    ) throws {
        let mutation = try mutationFrom(entity, operation, changes)
        
        let state = try context.fetch(
            MutationQueries.getEntitySyncState(entity.id)
        ).first
        
        let newState = EntitySyncState(
            entityId: entity.id,
            lastMutationId: mutation.id,
            revision: 1
        )

        if state != nil {
            mutation.expectedMutationId = state!.lastMutationId
            mutation.expectedRevision = state!.revision
            
            state!.revision += 1
            state!.lastMutationId = mutation.id
            
        } else {
            context.insert(newState)
        }

        context.insert(mutation)
    }

    private func mutationFrom<T: Entity>(
        _ entity: T,
        _ operation: SyncOperation,
        _ changes: String?
    ) throws -> Mutation {

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
