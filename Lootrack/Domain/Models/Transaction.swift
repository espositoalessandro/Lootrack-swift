import Foundation
import SwiftData

enum TransactionType: String, Codable {
    case expense
    case income
}

@Model
final class Transaction: Entity {
    @Attribute(.unique)
    var id: UUID

    var revision: Int?
    var lastMutationId: UUID?

    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    var type: TransactionType
    var amountInCents: Int
    var note: String
    var occurredOn: String
    var categoryId: UUID?

    init(
        id: UUID = UUID(),
        revision: Int? = nil,
        lastMutationId: UUID? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        deletedAt: Date? = nil,
        type: TransactionType,
        amountInCents: Int,
        note: String,
        occurredOn: String,
        categoryId: UUID? = nil,
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.type = type
        self.amountInCents = amountInCents
        self.note = note
        self.occurredOn = occurredOn
        self.categoryId = categoryId
        self.revision = revision
        self.lastMutationId = lastMutationId
    }
}
