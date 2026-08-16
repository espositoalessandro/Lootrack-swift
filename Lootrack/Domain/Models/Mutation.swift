import Foundation
import SwiftData

enum EntityRef {
    case transaction(Transaction)
    case category(Category)
}

enum SyncEntityType: String, Codable {
    case transaction
    case category
}

enum SyncOperation: String, Codable {
    case upsert
    case delete
}

enum MutationValue: Codable, Equatable {
    case string(String)
    case int(Int)
    case date(Date)
    case uuid(UUID)
    case transactionType(TransactionType)
    case null
}

struct MutationChange: Codable {
    let field: String
    let before: MutationValue
    let after: MutationValue
}

extension MutationChange {
    static func ifChanged(
        field: String,
        from before: MutationValue,
        to after: MutationValue
    ) -> MutationChange? {
        guard before != after else {
            return nil
        }
        
        return MutationChange(
            field: field,
            before: before,
            after: after
        )
    }
}

@Model
final class Mutation: ImmutableEntity {
    @Attribute(.unique)
    var id: UUID
    private var _transaction: Transaction?
    private var _category: Category?
    var operation: SyncOperation
    var expectedRevision: Int?
    var expectedMutationId: UUID?
    var createdAt: Date
    var changes: [MutationChange]
    var entity: EntityRef {
        if let transaction = _transaction {
            return .transaction(transaction)
        }
        if let category = _category {
            return .category(category)
        }
        fatalError("Mutation has no associated entity")
    }

    init(
        id: UUID = UUID(),
        entity: EntityRef,
        operation: SyncOperation,
        expectedRevision: Int? = nil,
        expectedMutationId: UUID? = nil,
        createdAt: Date = .now,
        changes: [MutationChange] = []
    ) {
        self.id = id
        self.operation = operation
        self.expectedRevision = expectedRevision
        self.expectedMutationId = expectedMutationId
        self.createdAt = createdAt
        self.changes = changes

        switch entity {
        case .transaction(let transaction):
            self._transaction = transaction
            self._category = nil
        case .category(let category):
            self._category = category
            self._transaction = nil
        }
    }
}

final class MutationDTO: Codable {
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
