import Foundation
import SwiftData

nonisolated enum SyncEntityType: String, Codable {
    case transaction
    case category
}

nonisolated enum SyncOperation: String, Codable {
    case upsert
    case delete
}

nonisolated struct SyncEntityKey: Hashable {
    let type: SyncEntityType
    let id: UUID
}

nonisolated enum EntitySnapshot: Codable {
    case transaction(TransactionDTO)
    case category(CategoryDTO)
}

extension EntitySnapshot {
    var id: UUID {
        switch self {
        case .transaction(let transaction):
            transaction.id
            
        case .category(let category):
            category.id
        }
    }
    
    var type: SyncEntityType {
        switch self {
        case .transaction:
                .transaction
            
        case .category:
                .category
        }
    }
}

@Model
final class Mutation: ImmutableEntity {
    @Attribute(.unique)
    var id: UUID
    var operation: SyncOperation
    var expectedRevision: Int?
    var expectedMutationId: UUID?
    var createdAt: Date
    var base: EntitySnapshot?
    var payload: EntitySnapshot

    init(
        id: UUID = UUID(),
        from base: EntitySnapshot?,
        to payload: EntitySnapshot,
        operation: SyncOperation,
        expectedRevision: Int? = nil,
        expectedMutationId: UUID? = nil,
        createdAt: Date = .now,
    ) {
        self.id = id
        self.operation = operation
        self.expectedRevision = expectedRevision
        self.expectedMutationId = expectedMutationId
        self.createdAt = createdAt
        self.base = base
        self.payload = payload
    }
}

final class MutationDTO: Codable, Identifiable {

    var id: UUID
    var entity: Data
    var operation: SyncOperation
    var expectedRevision: Int?
    var expectedMutationId: UUID?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        entity: Data,
        operation: SyncOperation,
        expectedRevision: Int? = nil,
        expectedMutationId: UUID? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.entity = entity
        self.operation = operation
        self.expectedRevision = expectedRevision
        self.expectedMutationId = expectedMutationId
        self.createdAt = createdAt
    }
}

@Model
final class EntitySyncState {
    @Attribute(.unique)
    var entityId: UUID

    var lastMutationId: UUID?
    var revision: Int

    init(
        entityId: UUID,
        lastMutationId: UUID? = nil,
        revision: Int
    ) {
        self.entityId = entityId
        self.lastMutationId = lastMutationId
        self.revision = revision
    }
}
