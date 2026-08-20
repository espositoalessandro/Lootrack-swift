import SwiftData
import SwiftUI

struct EditCategoryView: View {
    @Environment(\.dismiss)
    private var dismiss

    @Environment(CategoryService.self)
    private var categoryService

    @State
    private var error: CategoryServiceError?

    let category: Category

    @State
    private var draft: CategoryDraft

    @State
    private var subcategoryDrafts: [SubcategoryDraft] = []

    @State
    private var didLoadSubcategories = false

    @Query(TransactionQueries.active)
    private var transactions: [Transaction]

    @Query(SubcategoryQueries.activeByName)
    private var subcategories: [Subcategory]

    private var hasTransactions: Bool {
        transactions.contains { transaction in
            transaction.categoryId == category.id
        }
    }

    private var canSave: Bool {
        let categoryName = draft.name
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !categoryName.isEmpty else {
            return false
        }

        var foundNames = Set<String>()

        for subcategory in subcategoryDrafts {
            let name = subcategory.name
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !name.isEmpty else {
                return false
            }

            let key = name.lowercased()

            guard foundNames.insert(key).inserted else {
                return false
            }
        }

        return true
    }

    init(category: Category) {
        self.category = category

        _draft = State(initialValue: CategoryDraft(category: category))
    }

    var body: some View {
        NavigationStack {
            CategoryForm(draft: $draft,
                         typeDisabled: hasTransactions,
                         subcategories:
                         $subcategoryDrafts)
                .navigationTitle("Edit Category")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            save()
                        }
                        .disabled(!canSave)
                    }
                }
                .task {
                    loadSubcategoriesIfNeeded()
                }
        }.alert(error: $error) { _ in
            Button("OK") {}
        } message: { error in
            if let recoverySuggestion = error.recoverySuggestion {
                Text(recoverySuggestion)
            }
        }
    }

    private func loadSubcategoriesIfNeeded() {
        guard !didLoadSubcategories else {
            return
        }

        didLoadSubcategories = true

        subcategoryDrafts =
            subcategories
                .filter { subcategory in
                    subcategory.categoryId
                        == category.id
                }
                .map { subcategory in
                    SubcategoryDraft(subcategory: subcategory)
                }
    }

    private func save() {
        do {
            try categoryService.update(category,
                                       name: draft.name,
                                       type: draft.type,
                                       note: draft.note,
                                       subcategories: subcategoryDrafts.map { (id: $0.id, name: $0.name) })
            dismiss()
        } catch {
            self.error = error as? CategoryServiceError ?? .couldNotUpdate
        }
    }
}
