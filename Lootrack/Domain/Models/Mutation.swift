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

@Model
final class Mutation: ImmutableEntity {
    @Attribute(.unique)
    var id: UUID
    var entity: EntityRef
    var operation: SyncOperation
    var expectedRevision: Int?
    var expectedMutationId: UUID?
    var createdAt: Date
    var changes: String?
    
    init(
        id: UUID = UUID(),
        entity: EntityRef,
        operation: SyncOperation,
        expectedRevision: Int? = nil,
        expectedMutationId: UUID? = nil,
        createdAt: Date = .now,
        changes: String? = nil
    ) {
        self.id = id
        self.entity = entity
        self.operation = operation
        self.expectedRevision = expectedRevision
        self.expectedMutationId = expectedMutationId
        self.createdAt = createdAt
        self.changes = changes
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

    var mutationId: UUID
    var lastMutationId: UUID?
    var revision: Int

    init(
        entityId: UUID,
        mutationId: UUID,
        lastMutationId: UUID? = nil,
        revision: Int
    ) {
        self.entityId = entityId
        self.mutationId = mutationId
        self.lastMutationId = lastMutationId
        self.revision = revision
    }
}
