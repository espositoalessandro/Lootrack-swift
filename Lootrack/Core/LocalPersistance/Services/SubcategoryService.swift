import Foundation
import Observation
import SwiftData

enum SubcategoryServiceError: Error {
    case emptyName
    case duplicateName
    case invalidIdentity
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

    func reconcile(categoryId: UUID,
                   desired: [(id: UUID, name: String)]) throws
    {
        let normalizedDesired = try validateAndNormalize(desired)

        let allSubcategories = try modelContext.fetch(FetchDescriptor<Subcategory>())

        let subcategoriesById = Dictionary(uniqueKeysWithValues:
            allSubcategories.map { subcategory in
                (subcategory.id, subcategory)
            })

        /*
         * Parent category is immutable.
         *
         * An existing UUID can only be reconciled inside
         * the category it was originally created for.
         */
        for item in normalizedDesired {
            if let existing = subcategoriesById[item.id] {
                guard existing.categoryId == categoryId,
                      existing.deletedAt == nil
                else {
                    throw SubcategoryServiceError
                        .invalidIdentity
                }
            }
        }

        let activeExisting = allSubcategories.filter {
            subcategory in
            subcategory.categoryId == categoryId
                && subcategory.deletedAt == nil
        }

        let desiredById = Dictionary(uniqueKeysWithValues:
            normalizedDesired.map { item in
                (item.id, item.name)
            })

        try modelContext.transaction {
            /*
             * Anything that existed before but is no longer
             * present in the edited draft is deleted.
             */
            for subcategory in activeExisting
                where desiredById[subcategory.id] == nil
            {
                try delete(subcategory)
            }

            /*
             * Existing IDs are renamed; unknown IDs are new
             * subcategories created by the Edit Category form.
             */
            for item in normalizedDesired {
                if let existing = subcategoriesById[item.id] {
                    try rename(existing,
                               to: item.name)
                } else {
                    try create(id: item.id,
                               categoryId: categoryId,
                               name: item.name)
                }
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
