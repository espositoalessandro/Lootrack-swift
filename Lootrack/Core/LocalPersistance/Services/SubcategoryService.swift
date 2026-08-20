internal import os
import Foundation
import Observation
import SwiftData

nonisolated enum SubcategoryServiceError: LocalizedError {
    case emptyName
    case duplicateName
    case invalidIdentity
    case couldNotUpdate

    var errorDescription: String? {
        switch self {
        case .emptyName:
            String(localized: "Subcategory name can't be empty.")
        case .duplicateName:
            String(localized: "Subcategory already exists.")
        case .invalidIdentity:
            String(localized: "Subcategory can't be updated.")
        case .couldNotUpdate:
            String(localized: "Subcategories couldn't be updated.")
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .emptyName:
            String(localized: "Enter a name for the subcategory.")
        case .duplicateName:
            String(localized: "Use a different name for this subcategory.")
        case .invalidIdentity:
            String(localized: "Reload the category and try again.")
        case .couldNotUpdate:
            String(localized: "Your subcategory changes weren't saved. Try again.")
        }
    }
}

@MainActor
@Observable
final class SubcategoryService {
    private let modelContext: ModelContext
    private let mutationService: MutationService

    init(modelContext: ModelContext,
         mutationService: MutationService)
    {
        self.modelContext = modelContext
        self.mutationService = mutationService
    }

    func reconcile(categoryId: UUID, desired: [(id: UUID, name: String)]) throws {
        do {
            try modelContext.transaction {
                try stageReconciliation(categoryId: categoryId, desired: desired)
            }
        } catch let error as SubcategoryServiceError {
            throw error
        } catch {
            modelContext.rollback()

            let errorDescription = String(describing: error)
            AppLogger.persistence.error("Failed to reconcile subcategories: \(errorDescription, privacy: .public)")

            throw SubcategoryServiceError.couldNotUpdate
        }
    }

    func stageReconciliation(categoryId: UUID, desired: [(id: UUID, name: String)]) throws {
        let normalizedDesired = try validateAndNormalize(desired)
        let allSubcategories = try modelContext.fetch(FetchDescriptor<Subcategory>())
        let subcategoriesById = Dictionary(uniqueKeysWithValues: allSubcategories.map { ($0.id, $0) })

        for item in normalizedDesired {
            if let existing = subcategoriesById[item.id] {
                guard existing.categoryId == categoryId, existing.deletedAt == nil else {
                    throw SubcategoryServiceError.invalidIdentity
                }
            }
        }

        let activeExisting = allSubcategories.filter {
            $0.categoryId == categoryId && $0.deletedAt == nil
        }

        let desiredById = Dictionary(uniqueKeysWithValues: normalizedDesired.map { ($0.id, $0.name) })

        for subcategory in activeExisting where desiredById[subcategory.id] == nil {
            try delete(subcategory)
        }

        for item in normalizedDesired {
            if let existing = subcategoriesById[item.id] {
                try rename(existing, to: item.name)
            } else {
                try create(id: item.id, categoryId: categoryId, name: item.name)
            }
        }
    }

    private func validateAndNormalize(_ desired: [(id: UUID, name: String)]) throws -> [(id: UUID, name: String)] {
        var foundNames = Set<String>()
        var foundIds = Set<UUID>()
        var result: [(id: UUID, name: String)] = []

        for item in desired {
            let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !name.isEmpty else {
                throw SubcategoryServiceError.emptyName
            }

            guard foundIds.insert(item.id).inserted else {
                throw SubcategoryServiceError.invalidIdentity
            }

            let key = normalizedName(name)

            guard foundNames.insert(key).inserted else {
                throw SubcategoryServiceError.duplicateName
            }

            result.append((id: item.id,
                           name: name))
        }

        return result
    }

    private func create(id: UUID,
                        categoryId: UUID,
                        name: String) throws
    {
        let now = Date.now

        let subcategory = Subcategory(id: id,
                                      createdAt: now,
                                      updatedAt: now,
                                      categoryId: categoryId,
                                      name: name)

        let snapshot = SubcategoryDTO(subcategory)

        try mutationService.createMutation(from: nil,
                                           to: .subcategory(snapshot),
                                           .upsert)

        modelContext.insert(subcategory)
    }

    private func rename(_ subcategory: Subcategory,
                        to name: String) throws
    {
        guard subcategory.name != name else {
            return
        }

        let now = Date.now
        let old = SubcategoryDTO(subcategory)

        let new = SubcategoryDTO(id: old.id,
                                 createdAt: old.createdAt,
                                 updatedAt: now,
                                 deletedAt: old.deletedAt,
                                 categoryId: old.categoryId,
                                 name: name)

        try mutationService.createMutation(from: .subcategory(old),
                                           to: .subcategory(new),
                                           .upsert)

        subcategory.name = name
        subcategory.updatedAt = now
    }

    private func delete(_ subcategory: Subcategory) throws {
        guard subcategory.deletedAt == nil else {
            return
        }

        let now = Date.now
        let old = SubcategoryDTO(subcategory)

        let deleted = SubcategoryDTO(id: old.id,
                                     createdAt: old.createdAt,
                                     updatedAt: now,
                                     deletedAt: now,
                                     categoryId: old.categoryId,
                                     name: old.name)

        try mutationService.createMutation(from: .subcategory(old),
                                           to: .subcategory(deleted),
                                           .delete)

        subcategory.deletedAt = now
        subcategory.updatedAt = now

        /*
         * Subcategory deletion is always allowed.
         *
         * Transactions remain intact; only their optional
         * subcategory reference is removed.
         */
        try clearTransactions(referencing: subcategory.id,
                              at: now)
    }

    private func clearTransactions(referencing subcategoryId: UUID,
                                   at now: Date) throws
    {
        let id = subcategoryId

        let transactions = try modelContext.fetch(FetchDescriptor<Transaction>(predicate:
            #Predicate<Transaction> {
                transaction in

                transaction.subcategoryId == id
            }))

        for transaction in transactions {
            let old = TransactionDTO(transaction)

            let updated = TransactionDTO(id: old.id,
                                         createdAt: old.createdAt,
                                         updatedAt: now,
                                         deletedAt: old.deletedAt,
                                         type: old.type,
                                         amountInCents: old.amountInCents,
                                         note: old.note,
                                         occurredOn: old.occurredOn,
                                         categoryId: old.categoryId,
                                         subcategoryId: nil,
                                         tags: old.tags)

            try mutationService.createMutation(from: .transaction(old),
                                               to: .transaction(updated),
                                               old.deletedAt == nil
                                                   ? .upsert
                                                   : .delete)

            transaction.subcategoryId = nil
            transaction.updatedAt = now
        }
    }

    private func normalizedName(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
