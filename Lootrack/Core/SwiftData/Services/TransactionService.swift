import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class TransactionService {
    private let modelContext: ModelContext
    private let sync: MutationService

    init(modelContext: ModelContext, sync: MutationService) {
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
        let now = Date.now

        let transaction = Transaction(
            createdAt: now,
            updatedAt: now,
            type: type,
            amountInCents: amountInCents,
            note: note,
            occurredOn: occurredOn,
            categoryId: categoryId
        )

        try sync.createMutation(
            from: nil,
            to: TransactionDTO.init(transaction),
            .upsert
        )

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
        let now = Date.now

        let old = TransactionDTO.init(transaction)
        transaction.type = type
        transaction.amountInCents = amountInCents
        transaction.note = note
        transaction.occurredOn = occurredOn
        transaction.categoryId = categoryId
        transaction.updatedAt = now
        let new = TransactionDTO.init(transaction)

        try sync.createMutation(
            from: old,
            to: new,
            .upsert,
        )
        try modelContext.save()
    }

    func delete(_ transaction: Transaction) throws {
        let now = Date.now

        let old = TransactionDTO.init(transaction)
        transaction.deletedAt = now
        transaction.updatedAt = now
        let new = TransactionDTO.init(transaction)

        try sync.createMutation(
            from: old,
            to: new,
            .upsert,
        )

        try modelContext.save()
    }
}
