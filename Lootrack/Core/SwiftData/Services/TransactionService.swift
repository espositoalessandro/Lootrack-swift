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

        let changes: [MutationChange] = [
            .init(
                field: "createdAt",
                before: .null,
                after: .date(now)
            ),
            .init(
                field: "updatedAt",
                before: .null,
                after: .date(now)
            ),
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
                after: categoryId.map(MutationValue.uuid) ?? .null
            ),
        ]

        try sync.createMutation(
            transaction,
            .upsert,
            changes
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

        var changes = [
            MutationChange.ifChanged(
                field: "type",
                from: .transactionType(transaction.type),
                to: .transactionType(type)
            ),
            MutationChange.ifChanged(
                field: "amountInCents",
                from: .int(transaction.amountInCents),
                to: .int(amountInCents)
            ),
            MutationChange.ifChanged(
                field: "note",
                from: .string(transaction.note),
                to: .string(note)
            ),
            MutationChange.ifChanged(
                field: "occurredOn",
                from: .date(transaction.occurredOn),
                to: .date(occurredOn)
            ),
            MutationChange.ifChanged(
                field: "categoryId",
                from: transaction.categoryId.map(MutationValue.uuid) ?? .null,
                to: categoryId.map(MutationValue.uuid) ?? .null
            ),
        ]
        .compactMap { $0 }

        guard !changes.isEmpty else {
            return
        }

        changes.append(
            .init(
                field: "updatedAt",
                before: .date(transaction.updatedAt),
                after: .date(now)
            )
        )

        try sync.createMutation(
            transaction,
            .upsert,
            changes
        )

        transaction.type = type
        transaction.amountInCents = amountInCents
        transaction.note = note
        transaction.occurredOn = occurredOn
        transaction.categoryId = categoryId
        transaction.updatedAt = now

        try modelContext.save()
    }

    func delete(_ transaction: Transaction) throws {
        let now = Date.now

        let changes: [MutationChange] = [
            .init(
                field: "deletedAt",
                before: transaction.deletedAt.map(MutationValue.date) ?? .null,
                after: .date(now)
            ),
            .init(
                field: "updatedAt",
                before: .date(transaction.updatedAt),
                after: .date(now)
            ),
        ]

        try sync.createMutation(
            transaction,
            .delete,
            changes
        )

        transaction.deletedAt = now
        transaction.updatedAt = now

        try modelContext.save()
    }
}
