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
    private let sync: Sync

    init(modelContext: ModelContext, sync: Sync) {
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
                field: "name",
                before: .null,
                after: .string(name)
            ),
        ]

        try sync.createMutation(
            category,
            .upsert,
            changes
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

        var changes = [
            MutationChange.ifChanged(
                field: "type",
                from: .transactionType(category.type),
                to: .transactionType(type)
            ),
            MutationChange.ifChanged(
                field: "name",
                from: .string(category.name),
                to: .string(name)
            ),
        ]
        .compactMap { $0 }

        guard !changes.isEmpty else {
            return
        }

        changes.append(
            .init(
                field: "updatedAt",
                before: .date(category.updatedAt),
                after: .date(now)
            )
        )

        try sync.createMutation(category, .upsert, changes)

        category.name = name
        category.type = type
        category.updatedAt = now

        try modelContext.save()
    }

    func delete(_ category: Category) throws {
        if try hasActiveTransactions(category) {
            throw CategoryServiceError.cannotDeleteWhileInUse
        }

        let now = Date.now

        let changes: [MutationChange] = [
            .init(
                field: "deletedAt",
                before: category.deletedAt.map(MutationValue.date) ?? .null,
                after: .date(now)
            ),
            .init(
                field: "updatedAt",
                before: .date(category.updatedAt),
                after: .date(now)
            ),
        ]

        try sync.createMutation(
            category,
            .delete,
            changes
        )

        category.deletedAt = now
        category.updatedAt = now

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
