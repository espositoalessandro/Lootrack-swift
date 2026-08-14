import SwiftUI
import SwiftData

struct EditCategoryView: View {
    @Environment(\.dismiss) private var dismiss

    let category: Category

    @State private var draft: CategoryDraft

    @Query(
        filter: #Predicate<Transaction> { transaction in
            transaction.deletedAt == nil
        }
    )
    private var transactions: [Transaction]

    private var hasTransactions: Bool {
        transactions.contains { transaction in
            transaction.categoryId == category.id
        }
    }

    init(category: Category) {
        self.category = category

        _draft = State(
            initialValue: CategoryDraft(category: category)
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(draft.name.isEmpty)
                }
            }
        }
    }

    private func save() {
        category.name = draft.name
        category.type = draft.type
        category.updatedAt = .now

        dismiss()
    }
}
