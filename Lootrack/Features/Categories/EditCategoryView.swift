import SwiftData
import SwiftUI

struct EditCategoryView: View {
    @Environment(\.dismiss)
    private var dismiss

    @Environment(CategoryService.self)
    private var categoryService

    let category: Category

    @State private var draft: CategoryDraft

    @Query(TransactionQueries.active)
    private var transactions: [Transaction]

    private var hasTransactions: Bool {
        transactions.contains { transaction in
            transaction.categoryId == category.id
        }
    }

    init(category: Category) {
        self.category = category

        _draft = State(
            initialValue: CategoryDraft(
                category: category
            )
        )
    }

    var body: some View {
        NavigationStack {
            CategoryForm(
                draft: $draft,
                typeDisabled: hasTransactions
            )
            .navigationTitle("Edit Category")
            .toolbar {
                ToolbarItem(
                    placement: .cancellationAction
                ) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(
                    placement: .confirmationAction
                ) {
                    Button("Save") {
                        save()
                    }
                    .disabled(draft.name.isEmpty)
                }
            }
        }
    }

    private func save() {
        do {
            try categoryService.update(
                category,
                name: draft.name,
                type: draft.type,
                note: draft.note
            )

            dismiss()
        } catch {
            print(
                "FAILED TO UPDATE CATEGORY:",
                error
            )
        }
    }
}
