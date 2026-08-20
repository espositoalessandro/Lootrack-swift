import Foundation
import SwiftData

nonisolated enum SyncEntityType: String, Codable, Hashable {
    case transaction
    case category
    case subcategory
}

nonisolated enum SyncOperation: String, Codable, Equatable {
    case upsert
    case delete
}

nonisolated struct SyncEntityKey: Hashable, Codable {
    let type: SyncEntityType
    let id: UUID
}

nonisolated enum EntitySnapshot:
    Codable,
    Equatable,
    Identifiable
{
    case transaction(TransactionDTO)
    case category(CategoryDTO)
    case subcategory(SubcategoryDTO)

    var id: UUID {
        switch self {
        case let .transaction(transaction):
            transaction.id

        case let .category(category):
            category.id

        case let .subcategory(subcategory):
            subcategory.id
        }
    }

    var type: SyncEntityType {
        switch self {
        case .transaction:
            .transaction

        case .category:
            .category

        case .subcategory:
            .subcategory
        }
    }

    var key: SyncEntityKey {
        SyncEntityKey(type: type,
                      id: id)
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

    init(id: UUID = UUID(),
         from base: EntitySnapshot?,
         to payload: EntitySnapshot,
         operation: SyncOperation,
         expectedRevision: Int? = nil,
         expectedMutationId: UUID? = nil,
         createdAt: Date = .now)
    {
        self.id = id
        self.operation = operation
        self.expectedRevision =
            expectedRevision
        self.expectedMutationId =
            expectedMutationId
        self.createdAt = createdAt
        self.base = base
        self.payload = payload
    }
}

@Model
final class EntitySyncState {
    @Attribute(.unique)
    var entityId: UUID

    var entityType: SyncEntityType
    var lastMutationId: UUID?
    var revision: Int

    var key: SyncEntityKey {
        SyncEntityKey(type: entityType,
                      id: entityId)
    }

    init(key: SyncEntityKey,
         lastMutationId: UUID? = nil,
         revision: Int)
    {
        entityId = key.id
        entityType = key.type
        self.lastMutationId =
            lastMutationId
        self.revision = revision
    }
}

nonisolated struct MutationDTO:
    Codable,
    Identifiable
{
    let id: UUID

    let operation: SyncOperation

    let expectedRevision: Int?
    let expectedMutationId: UUID?

    let createdAt: Date

    let base: EntitySnapshot?
    let payload: EntitySnapshot

    var entityId: UUID {
        payload.id
    }

    var entityType: SyncEntityType {
        payload.type
    }
}

extension MutationDTO {
    @MainActor
    init(_ mutation: Mutation) {
        id = mutation.id
        operation =
            mutation.operation
        expectedRevision =
            mutation.expectedRevision
        expectedMutationId =
            mutation.expectedMutationId
        createdAt =
            mutation.createdAt
        base = mutation.base
        payload = mutation.payload
    }
}

struct PendingEntityChanges:
    Identifiable
{
    let mutations: [Mutation]

    init(mutations: [Mutation]) {
        precondition(!mutations.isEmpty)

        self.mutations = mutations
    }

    var id: SyncEntityKey {
        latestMutation.payload.key
    }

    var entity: EntitySnapshot {
        latestMutation.payload
    }

    var latestMutation: Mutation {
        mutations.last!
    }
}
