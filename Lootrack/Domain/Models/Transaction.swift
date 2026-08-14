import Foundation
import SwiftData

enum TransactionType: String, Codable {
    case expense
    case income
}

@Model
final class Transaction {
    @Attribute(.unique)
    var id: UUID

    var revision: Int?
    var lastMutationId: String?

    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    var type: TransactionType
    var amountInCents: Int
    var note: String
    var occurredOn: Date

    var categoryId: UUID?

    init(
        id: UUID = UUID(),
        revision: Int? = nil,
        lastMutationId: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        deletedAt: Date? = nil,
        type: TransactionType,
        amountInCents: Int,
        note: String,
        occurredOn: Date,
        categoryId: UUID? = nil
    ) {
        self.id = id

        self.revision = revision
        self.lastMutationId = lastMutationId

        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt

        self.type = type
        self.amountInCents = amountInCents
        self.note = note
        self.occurredOn = occurredOn

        self.categoryId = categoryId
    }
}
