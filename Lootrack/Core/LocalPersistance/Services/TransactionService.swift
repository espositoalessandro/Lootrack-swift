import Foundation
import Observation
import SwiftData

enum TransactionServiceError: Error {
    case subcategoryRequiresCategory
    case invalidSubcategory
}

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
        categoryId: UUID?,
        subcategoryId: UUID?
    ) throws -> Transaction {
        try validateSubcategory(
            categoryId: categoryId,
            subcategoryId: subcategoryId
        )

        let now = Date.now

        let transaction = Transaction(
            createdAt: now,
            updatedAt: now,
            type: type,
            amountInCents: amountInCents,
            note: note,
            occurredOn: occurredOn,
            categoryId: categoryId,
            subcategoryId: subcategoryId
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
        categoryId: UUID?,
        subcategoryId: UUID?
    ) throws {
        try validateSubcategory(
            categoryId: categoryId,
            subcategoryId: subcategoryId
        )

        guard
            transaction.type != type
                || transaction.amountInCents
                    != amountInCents
                || transaction.note != note
                || transaction.occurredOn
                    != occurredOn
                || transaction.categoryId
                    != categoryId
                || transaction.subcategoryId
                    != subcategoryId
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
            categoryId: categoryId,
            subcategoryId: subcategoryId
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
        transaction.subcategoryId = subcategoryId
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
            categoryId: old.categoryId,
            subcategoryId: old.subcategoryId
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

        let restoredSubcategoryId =
            try validSubcategoryId(
                categoryId: old.categoryId,
                subcategoryId: old.subcategoryId
            )

        let restored = TransactionDTO(
            id: old.id,
            createdAt: old.createdAt,
            updatedAt: now,
            deletedAt: nil,
            type: old.type,
            amountInCents: old.amountInCents,
            note: old.note,
            occurredOn: old.occurredOn,
            categoryId: old.categoryId,
            subcategoryId: restoredSubcategoryId
        )

        try mutationService.createMutation(
            from: .transaction(old),
            to: .transaction(restored),
            .upsert
        )

        transaction.deletedAt = nil
        transaction.subcategoryId = restoredSubcategoryId
        transaction.updatedAt = now

        try modelContext.save()
    }

    private func validateSubcategory(
        categoryId: UUID?,
        subcategoryId: UUID?
    ) throws {
        guard subcategoryId != nil else {
            return
        }

        guard categoryId != nil else {
            throw TransactionServiceError
                .subcategoryRequiresCategory
        }

        guard
            try validSubcategoryId(
                categoryId: categoryId,
                subcategoryId: subcategoryId
            ) != nil
        else {
            throw TransactionServiceError
                .invalidSubcategory
        }
    }

    private func validSubcategoryId(
        categoryId: UUID?,
        subcategoryId: UUID?
    ) throws -> UUID? {
        guard
            let categoryId,
            let subcategoryId
        else {
            return nil
        }

        let id = subcategoryId

        let subcategory = try modelContext.fetch(
            FetchDescriptor<Subcategory>(
                predicate:
                    #Predicate<Subcategory> {
                        subcategory in

                        subcategory.id == id
                    }
            )
        ).first

        guard
            let subcategory,
            subcategory.deletedAt == nil,
            subcategory.categoryId == categoryId
        else {
            return nil
        }

        return subcategoryId
    }
}
