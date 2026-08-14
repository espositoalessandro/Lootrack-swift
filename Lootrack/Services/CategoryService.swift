import Foundation
import Observation
import SwiftData

enum CategoryServiceError: Error {
    case cannotChangeTypeWhileInUse
}

@MainActor
@Observable
final class CategoryService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    @discardableResult
    func create(
        name: String,
        type: TransactionType
    ) throws -> Category {
        let category = Category(
            type: type,
            name: name
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
           try hasActiveTransactions(category) {
            throw CategoryServiceError.cannotChangeTypeWhileInUse
        }

        category.name = name
        category.type = type
        category.updatedAt = .now

        try modelContext.save()
    }

    func delete(_ category: Category) throws {
        category.deletedAt = .now
        category.updatedAt = .now

        try modelContext.save()
    }

    private func hasActiveTransactions(
        _ category: Category
    ) throws -> Bool {
        let categoryId = category.id

        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { transaction in
                transaction.deletedAt == nil &&
                transaction.categoryId == categoryId
            }
        )

        return try !modelContext.fetch(descriptor).isEmpty
    }
}
