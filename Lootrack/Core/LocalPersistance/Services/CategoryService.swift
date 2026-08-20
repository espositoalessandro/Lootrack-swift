internal import os
import Foundation
import Observation
import SwiftData

nonisolated enum CategoryServiceError: LocalizedError {
    case cannotChangeTypeWhileInUse
    case cannotDeleteWhileInUse
    case couldNotCreate
    case couldNotUpdate
    case couldNotDelete
    case couldNotRestore
    case subcategory(SubcategoryServiceError)

    var errorDescription: String? {
        switch self {
        case .cannotChangeTypeWhileInUse:
            String(localized: "Category type can't be changed.")
        case .cannotDeleteWhileInUse:
            String(localized: "Category can't be deleted.")
        case .couldNotCreate:
            String(localized: "Category couldn't be created.")
        case .couldNotUpdate:
            String(localized: "Category couldn't be updated.")
        case .couldNotDelete:
            String(localized: "Category couldn't be deleted.")
        case .couldNotRestore:
            String(localized: "Category couldn't be restored.")
        case let .subcategory(error):
            error.errorDescription
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .cannotChangeTypeWhileInUse:
            String(localized: "This category is used by one or more transactions.")
        case .cannotDeleteWhileInUse:
            String(localized: "Reassign or delete the transactions using this category first.")
        case .couldNotCreate:
            String(localized: "Your category wasn't saved. Try again.")
        case .couldNotUpdate:
            String(localized: "Your changes weren't saved. Try again.")
        case .couldNotDelete:
            String(localized: "The category wasn't deleted. Try again.")
        case .couldNotRestore:
            String(localized: "The category wasn't restored. Try again.")
        case let .subcategory(error):
            error.recoverySuggestion
        }
    }
}

@MainActor
@Observable
final class CategoryService {
    private let modelContext: ModelContext
    private let mutationService: MutationService
    private let subcategoryService: SubcategoryService

    init(modelContext: ModelContext,
         mutationService: MutationService,
         subcategoryService: SubcategoryService)
    {
        self.modelContext = modelContext
        self.mutationService = mutationService
        self.subcategoryService = subcategoryService
    }

    @discardableResult
    func create(name: String,
                type: TransactionType,
                note: String) throws -> Category
    {
        do {
            let now = Date.now
            let category = Category(createdAt: now,
                                    updatedAt: now,
                                    type: type,
                                    name: name,
                                    note: note)

            let snapshot = CategoryDTO(category)

            try modelContext.transaction {
                try mutationService.createMutation(from: nil,
                                                   to: .category(snapshot),
                                                   .upsert)
                modelContext.insert(category)
            }

            return category
        } catch let error as CategoryServiceError {
            throw error
        } catch {
            modelContext.rollback()

            let errorDescription = String(describing: error)
            AppLogger.persistence.error("Failed to create category: \(errorDescription, privacy: .public)")

            throw CategoryServiceError.couldNotCreate
        }
    }

    func update(_ category: Category,
                name: String,
                type: TransactionType,
                note: String,
                subcategories desiredSubcategories: [(id: UUID, name: String)]) throws
    {
        do {
            let categoryChanged = category.name != name || category.type != type || category.note != note

            if category.type != type, try hasActiveTransactions(category) {
                throw CategoryServiceError.cannotChangeTypeWhileInUse
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

            try modelContext.transaction {
                try subcategoryService.stageReconciliation(categoryId: category.id, desired: desiredSubcategories)

                guard categoryChanged else {
                    return
                }

                try mutationService.createMutation(from: .category(old), to: .category(new), .upsert)

                category.name = name
                category.type = type
                category.note = note
                category.updatedAt = now
            }
        } catch let error as CategoryServiceError {
            throw error
        } catch let error as SubcategoryServiceError {
            throw CategoryServiceError.subcategory(error)
        } catch {
            modelContext.rollback()

            let errorDescription = String(describing: error)
            AppLogger.persistence.error("Failed to update category: \(errorDescription, privacy: .public)")

            throw CategoryServiceError.couldNotUpdate
        }
    }

    func delete(_ category: Category) throws {
        guard category.deletedAt == nil else {
            return
        }

        do {
            if try hasActiveTransactions(category) {
                throw CategoryServiceError.cannotDeleteWhileInUse
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

            try modelContext.transaction {
                try mutationService.createMutation(from: .category(old),
                                                   to: .category(new),
                                                   .delete)

                category.deletedAt = now
                category.updatedAt = now
            }
        } catch let error as CategoryServiceError {
            throw error
        } catch {
            modelContext.rollback()

            let errorDescription = String(describing: error)
            AppLogger.persistence.error("Failed to delete category: \(errorDescription, privacy: .public)")

            throw CategoryServiceError.couldNotDelete
        }
    }

    func restore(_ category: Category) throws {
        guard category.deletedAt != nil else {
            return
        }

        do {
            let now = Date.now
            let old = CategoryDTO(category)
            let restored = CategoryDTO(id: old.id,
                                       createdAt: old.createdAt,
                                       updatedAt: now,
                                       deletedAt: nil,
                                       type: old.type,
                                       name: old.name,
                                       note: old.note)

            try modelContext.transaction {
                try mutationService.createMutation(from: .category(old),
                                                   to: .category(restored),
                                                   .upsert)

                category.deletedAt = nil
                category.updatedAt = now
            }
        } catch let error as CategoryServiceError {
            throw error
        } catch {
            modelContext.rollback()

            let errorDescription = String(describing: error)
            AppLogger.persistence.error("Failed to restore category: \(errorDescription, privacy: .public)")

            throw CategoryServiceError.couldNotRestore
        }
    }

    private func hasActiveTransactions(_ category: Category) throws -> Bool {
        let categoryId = category.id
        let descriptor = FetchDescriptor<Transaction>(predicate:
            #Predicate<Transaction> { transaction in
                transaction.deletedAt == nil && transaction.categoryId == categoryId
            })

        return try !modelContext.fetch(descriptor).isEmpty
    }
}
