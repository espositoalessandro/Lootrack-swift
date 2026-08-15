import Foundation
import SwiftData

enum SyncEntityType: String, CaseIterable {
    case transaction
    case category
}

enum SyncOperation: String, CaseIterable {
    case upsert
    case delete
}

protocol Syncable {
    var revision: Int? { get set }
    var lastMutationId: String? { get set }
}

@Model
final class SyncMutation: Identifiable {
    @Attribute(.unique)
    var id: UUID
    
    var entityType: SyncEntityType
    var entityId: UUID
    var operation: SyncOperation
    var expectedRevision: Int
    var expectedMutationId: UUID
    var basePayloadJson: String
    var payloadJson: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        entityType: SyncEntityType,
        entityId: UUID,
        operation: SyncOperation,
        expectedRevision: Int,
        expectedMutationId: UUID,
        basePayloadJson: String,
        payloadJson: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.entityType = entityType
        self.entityId = entityId
        self.operation = operation
        self.expectedRevision = expectedRevision
        self.expectedMutationId = expectedMutationId
        self.basePayloadJson = basePayloadJson
        self.payloadJson = payloadJson
        self.createdAt = createdAt
    }
}
