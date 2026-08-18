import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class TransactionService {
    private let modelContext: ModelContext
    private let mutationService: MutationService

    init(
        modelContext: ModelContext,
        mutationService: MutationService
    ) {
        self.modelContext = modelContext
        self.mutationService = mutationService
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

        let snapshot = TransactionDTO(
            transaction
        )

        try mutationService.createMutation(
            from: nil,
            to: .transaction(snapshot),
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
        guard
            transaction.type != type
                || transaction.amountInCents
                    != amountInCents
                || transaction.note != note
                || transaction.occurredOn
                    != occurredOn
                || transaction.categoryId
                    != categoryId
        else {
            return
        }

        let now = Date.now

        let old = TransactionDTO(transaction)

        let new = TransactionDTO(
            id: old.id,
            createdAt: old.createdAt,
            updatedAt: now,
            deletedAt: old.deletedAt,
            type: type,
            amountInCents: amountInCents,
            note: note,
            occurredOn: occurredOn,
            categoryId: categoryId
        )

        try mutationService.createMutation(
            from: .transaction(old),
            to: .transaction(new),
            .upsert
        )

        transaction.type = type
        transaction.amountInCents =
            amountInCents
        transaction.note = note
        transaction.occurredOn = occurredOn
        transaction.categoryId = categoryId
        transaction.updatedAt = now

        try modelContext.save()
    }

    func delete(
        _ transaction: Transaction
    ) throws {
        guard transaction.deletedAt == nil else {
            return
        }

        let now = Date.now

        let old = TransactionDTO(transaction)

        let new = TransactionDTO(
            id: old.id,
            createdAt: old.createdAt,
            updatedAt: now,
            deletedAt: now,
            type: old.type,
            amountInCents: old.amountInCents,
            note: old.note,
            occurredOn: old.occurredOn,
            categoryId: old.categoryId
        )

        try mutationService.createMutation(
            from: .transaction(old),
            to: .transaction(new),
            .delete
        )

        transaction.deletedAt = now
        transaction.updatedAt = now

        try modelContext.save()
    }

    func restore(
        _ transaction: Transaction
    ) throws {
        guard transaction.deletedAt != nil else {
            return
        }

        let now = Date.now

        let old = TransactionDTO(transaction)

        let restored = TransactionDTO(
            id: old.id,
            createdAt: old.createdAt,
            updatedAt: now,
            deletedAt: nil,
            type: old.type,
            amountInCents: old.amountInCents,
            note: old.note,
            occurredOn: old.occurredOn,
            categoryId: old.categoryId
        )

        try mutationService.createMutation(
            from: .transaction(old),
            to: .transaction(restored),
            .upsert
        )

        transaction.deletedAt = nil
        transaction.updatedAt = now

        try modelContext.save()
    }
}
