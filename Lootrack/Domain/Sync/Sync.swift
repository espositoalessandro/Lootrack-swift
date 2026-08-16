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

func encode<T: Encodable>(_ value: T) throws -> Data {
    return try JSONEncoder().encode(value)
}

func mutationFrom<T: Entity>(
    _ entity: T,
    previous: T?,
    operation: SyncOperation
) throws -> SyncMutation {

    var mutationId = UUID()
    let entityType: SyncEntityType
    let payload: Data
    let basePayload: Data?

    switch entity {
    case let transaction as Transaction:
        entityType = .transaction
        transaction.lastMutationId = mutationId
        payload = try encode(TransactionDTO(transaction: transaction))
        basePayload =
            previous != nil
            ? try encode(TransactionDTO(transaction: previous as! Transaction))
            : nil

    case let category as Category:
        entityType = .category
        category.lastMutationId = mutationId
        payload = try encode(CategoryDTO(category: category))
        basePayload =
            previous != nil
            ? try encode(CategoryDTO(category: previous as! Category)) : nil

    default:
        fatalError("Unsupported entity type: \(type(of: entity))")
    }

    return .init(
        id: mutationId,
        entityType: entityType,
        entityId: entity.id,
        operation: operation,
        expectedRevision: previous?.revision,
        expectedMutationId: previous?.lastMutationId,
        basePayload: basePayload,
        payload: payload,
    )
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
