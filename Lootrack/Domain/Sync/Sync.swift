import Foundation
import SwiftData

enum SyncEntityType: String, Codable {
    case transaction
    case category
}

enum SyncOperation: String, Codable {
    case upsert
    case delete
}

nonisolated protocol Syncable {
    var revision: Int? { get set }
    var lastMutationId: UUID? { get set }
}

@Model
final class SyncMutation {
    @Attribute(.unique)
    var id: UUID
    
    var entityType: SyncEntityType
    var entityId: UUID
    var operation: SyncOperation
    var expectedRevision: Int?
    var expectedMutationId: UUID?
    var basePayload: Data?
    var payload: Data
    var createdAt: Date

    init(
        id: UUID = UUID(),
        entityType: SyncEntityType,
        entityId: UUID,
        operation: SyncOperation,
        expectedRevision: Int? = nil,
        expectedMutationId: UUID? = nil,
        basePayload: Data? = nil,
        payload: Data,
        createdAt: Date = .now
    ) {
        self.id = id
        self.entityType = entityType
        self.entityId = entityId
        self.operation = operation
        self.expectedRevision = expectedRevision
        self.expectedMutationId = expectedMutationId
        self.basePayload = basePayload
        self.payload = payload
        self.createdAt = createdAt
    }
}
