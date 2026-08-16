import Foundation
import SwiftData

nonisolated enum TransactionType: String, Codable {
    case expense
    case income
}

@Model
final class Transaction: Entity {
    @Attribute(.unique)
    var id: UUID

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
        createdAt: Date = .now,
        updatedAt: Date = .now,
        deletedAt: Date? = nil,
        type: TransactionType,
        amountInCents: Int,
        note: String,
        occurredOn: Date,
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
    }
}

struct TransactionDTO: Codable {
    let id: UUID

    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    
    let type: TransactionType
    let amountInCents: Int
    let note: String
    let occurredOn: Date
    let categoryId: UUID?
}

extension TransactionDTO {
    init(transaction: Transaction) {
        self.id = transaction.id
        self.createdAt = transaction.createdAt
        self.updatedAt = transaction.updatedAt
        self.deletedAt = transaction.deletedAt
        self.type = transaction.type
        self.amountInCents = transaction.amountInCents
        self.note = transaction.note
        self.occurredOn = transaction.occurredOn
        self.categoryId = transaction.categoryId
    }
}
