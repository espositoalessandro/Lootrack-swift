import Foundation

struct TransactionDTO: Codable {
    let id: UUID
    
    let revision: Int?
    let lastMutationId: UUID?
    
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
        self.revision = transaction.revision
        self.lastMutationId = transaction.lastMutationId
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
