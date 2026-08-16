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

        let changes: [MutationChange] = [
            .init(
                field: "type",
                before: .null,
                after: .transactionType(type)
            ),
            .init(
                field: "amountInCents",
                before: .null,
                after: .int(amountInCents)
            ),
            .init(
                field: "note",
                before: .null,
                after: .string(note)
            ),
            .init(
                field: "occurredOn",
                before: .null,
                after: .date(occurredOn)
            ),
            .init(
                field: "categoryId",
                before: .null,
                after: categoryId != nil ? .uuid(categoryId!) : .null
            ),
            .init(
                field: "updatedAt",
                before: .date(transaction.updatedAt),
                after: .date(.now)
            ),
        ]

        try sync.createMutation(transaction, .upsert, changes)
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
        let now: Date = .now
        let changes: [MutationChange] = [
            .init(
                field: "type",
                before: .transactionType(transaction.type),
                after: .transactionType(type)
            ),
            .init(
                field: "amountInCents",
                before: .int(transaction.amountInCents),
                after: .int(amountInCents)
            ),
            .init(
                field: "note",
                before: .string(transaction.note),
                after: .string(note)
            ),
            .init(
                field: "occurredOn",
                before: .date(transaction.occurredOn),
                after: .date(occurredOn)
            ),
            .init(
                field: "categoryId",
                before: transaction.categoryId != nil
                    ? .uuid(transaction.categoryId!) : .null,
                after: categoryId != nil ? .uuid(categoryId!) : .null
            ),
            .init(
                field: "updatedAt",
                before: .date(transaction.updatedAt),
                after: .date(now)
            ),
        ]

        try sync.createMutation(transaction, .upsert, changes)

        transaction.type = type
        transaction.amountInCents = amountInCents
        transaction.note = note
        transaction.occurredOn = occurredOn
        transaction.categoryId = categoryId
        transaction.updatedAt = now

        try modelContext.save()
    }

    func delete(_ transaction: Transaction) throws {
        let now: Date = .now
        let changes: [MutationChange] = [
            .init(
                field: "deletedAt",
                before: .null,
                after: .date(now)
            ),
            .init(
                field: "updatedAt",
                before: .date(transaction.updatedAt),
                after: .date(now)
            ),
        ]

        try sync.createMutation(transaction, .delete, changes)

        transaction.deletedAt = now
        transaction.updatedAt = now

        try modelContext.save()
    }
}
