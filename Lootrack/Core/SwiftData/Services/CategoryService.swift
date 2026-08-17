import Foundation
import Observation
import SwiftData

enum CategoryServiceError: Error {
    case cannotChangeTypeWhileInUse
    case cannotDeleteWhileInUse
}

@MainActor
@Observable
final class CategoryService {
    private let modelContext: ModelContext
    private let sync: MutationService

    init(modelContext: ModelContext, sync: MutationService) {
        self.modelContext = modelContext
        self.sync = sync
    }

    @discardableResult
    func create(
        name: String,
        type: TransactionType
    ) throws -> Category {
        let now = Date.now

        let category = Category(
            createdAt: now,
            updatedAt: now,
            type: type,
            name: name
        )

        try sync.createMutation(
            from: nil,
            to: CategoryDTO.init(category),
            .upsert,
        )

        modelContext.insert(category)
        try modelContext.save()

        return category
    }

    func update(
        _ category: Category,
        name: String,
        type: TransactionType
    ) throws {
        if category.type != type,
            try hasActiveTransactions(category)
        {
            throw CategoryServiceError.cannotChangeTypeWhileInUse
        }

        let now = Date.now

        let old: CategoryDTO = .init(category)
        category.name = name
        category.type = type
        category.updatedAt = now
        let new: CategoryDTO = .init(category)

        try sync.createMutation(
            from: old,
            to: new,
            .upsert,
        )

        try modelContext.save()
    }

    func delete(_ category: Category) throws {
        if try hasActiveTransactions(category) {
            throw CategoryServiceError.cannotDeleteWhileInUse
        }

        let now = Date.now

        let old: CategoryDTO = .init(category)

        category.deletedAt = now
        category.updatedAt = now

        let new: CategoryDTO = .init(category)

        try sync.createMutation(
            from: old,
            to: new,
            .delete,
        )

        try modelContext.save()
    }

    private func hasActiveTransactions(
        _ category: Category
    ) throws -> Bool {
        let categoryId = category.id

        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { transaction in
                transaction.deletedAt == nil
                    && transaction.categoryId == categoryId
            }
        )

        return try !modelContext.fetch(descriptor).isEmpty
    }
}
