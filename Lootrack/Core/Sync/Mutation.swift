import Foundation
import SwiftData

nonisolated enum SyncEntityType: String, Codable, Hashable {
    case transaction
    case category
}

nonisolated enum SyncOperation: String, Codable, Equatable {
    case upsert
    case delete
}

nonisolated struct SyncEntityKey: Hashable, Codable {
    let type: SyncEntityType
    let id: UUID
}

nonisolated enum EntitySnapshot: Codable, Equatable, Identifiable {
    case transaction(TransactionDTO)
    case category(CategoryDTO)

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
            return .transaction

        case .category:
            return .category
        }
    }

    var key: SyncEntityKey {
        SyncEntityKey(
            type: type,
            id: id
        )
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
        createdAt: Date = .now
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
