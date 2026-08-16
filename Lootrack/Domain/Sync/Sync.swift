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
        let existingRelationships = try context.fetch(
            MutationQueries.getRelationshipsByEntityId(entity.id)
        )
        let mutationToEntity = Relationship(
            entityId: entity.id,
            mutationId: mutation.id,
            revision: 1
        )
        
        if !existingRelationships.isEmpty {
            mutationToEntity.revision = existingRelationships[0].revision + 1
        }
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
