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
    private let mutationService: MutationService

    init(modelContext: ModelContext,
         mutationService: MutationService)
    {
        self.modelContext = modelContext
        self.mutationService = mutationService
    }

    @discardableResult
    func create(name: String,
                type: TransactionType,
                note: String) throws -> Category
    {
        let now = Date.now

        let category = Category(createdAt: now,
                                updatedAt: now,
                                type: type,
                                name: name,
                                note: note)

        let snapshot = CategoryDTO(category)

        try mutationService.createMutation(from: nil,
                                           to: .category(snapshot),
                                           .upsert)

        modelContext.insert(category)

        try modelContext.save()

        return category
    }

    func update(_ category: Category,
                name: String,
                type: TransactionType,
                note: String) throws
    {
        guard
            category.name != name
            || category.type != type
            || category.note != note
        else {
            return
        }

        if category.type != type,
           try hasActiveTransactions(category)
        {
            throw CategoryServiceError
                .cannotChangeTypeWhileInUse
        }

        let now = Date.now

        let old = CategoryDTO(category)

        let new = CategoryDTO(id: old.id,
                              createdAt: old.createdAt,
                              updatedAt: now,
                              deletedAt: old.deletedAt,
                              type: type,
                              name: name,
                              note: note)

        try mutationService.createMutation(from: .category(old),
                                           to: .category(new),
                                           .upsert)

        category.name = name
        category.type = type
        category.note = note
        category.updatedAt = now

        try modelContext.save()
    }

    func delete(_ category: Category) throws {
        guard category.deletedAt == nil else {
            return
        }

        if try hasActiveTransactions(category) {
            throw CategoryServiceError
                .cannotDeleteWhileInUse
        }

        let now = Date.now

        let old = CategoryDTO(category)

        let new = CategoryDTO(id: old.id,
                              createdAt: old.createdAt,
                              updatedAt: now,
                              deletedAt: now,
                              type: old.type,
                              name: old.name,
                              note: old.note)

        try mutationService.createMutation(from: .category(old),
                                           to: .category(new),
                                           .delete)

        category.deletedAt = now
        category.updatedAt = now

        try modelContext.save()
    }

    func restore(_ category: Category) throws {
        guard category.deletedAt != nil else {
            return
        }

        let now = Date.now

        let old = CategoryDTO(category)

        let restored = CategoryDTO(id: old.id,
                                   createdAt: old.createdAt,
                                   updatedAt: now,
                                   deletedAt: nil,
                                   type: old.type,
                                   name: old.name,
                                   note: old.note)

        try mutationService.createMutation(from: .category(old),
                                           to: .category(restored),
                                           .upsert)

        category.deletedAt = nil
        category.updatedAt = now

        try modelContext.save()
    }

    private func hasActiveTransactions(_ category: Category) throws -> Bool {
        let categoryId = category.id

        let descriptor =
            FetchDescriptor<Transaction>(predicate:
                #Predicate<Transaction> {
                    transaction in

                    transaction.deletedAt == nil
                        && transaction.categoryId
                        == categoryId
                })

        return try
            !modelContext
            .fetch(descriptor)
            .isEmpty
    }
}
