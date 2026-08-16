import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class TransactionService {
    private let modelContext: ModelContext
    private let sync: Sync

    init(modelContext: ModelContext, sync: Sync) {
        self.modelContext = modelContext
        self.sync = sync
    }

    @discardableResult
    func create(
        type: TransactionType,
        amountInCents: Int,
        note: String,
        occurredOn: Date,
        categoryId: UUID?
    ) throws -> Transaction {
        
        let transaction = Transaction(
            type: type,
            amountInCents: amountInCents,
            note: note,
            occurredOn: occurredOn,
            categoryId: categoryId
        )

        try sync.createMutation(transaction, .upsert, nil)
        modelContext.insert(transaction)
        try modelContext.save()

        return transaction
    }

    func update(
        _ transaction: Transaction,
        type: TransactionType,
        amountInCents: Int,
        note: String,
        occurredOn: Date,
        categoryId: UUID?
    ) throws {
        
        try sync.createMutation(transaction, .upsert, nil)

        transaction.type = type
        transaction.amountInCents = amountInCents
        transaction.note = note
        transaction.occurredOn = occurredOn
        transaction.categoryId = categoryId
        transaction.updatedAt = .now

        try modelContext.save()
    }

    func delete(_ transaction: Transaction) throws {
        
        try sync.createMutation(transaction, .delete, nil)

        transaction.deletedAt = .now
        transaction.updatedAt = .now

        try modelContext.save()
    }
}
