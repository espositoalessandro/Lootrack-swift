import SwiftUI

struct AddTransactionView: View {
    @Environment(\.dismiss)
    private var dismiss

    @Environment(TransactionService.self)
    private var transactionService

    @State
    private var draft = TransactionDraft()

    @State
    private var error: TransactionServiceError?

    var body: some View {
        NavigationStack {
            TransactionForm(
                draft: $draft,
                autoSelectCategoryWithAI: true,
                autoSelectSubcategoryWithAI: true,
                quickAmountEntry: true
            )
            .navigationTitle("New Transaction")
            .toolbar {
                ToolbarItem(
                    placement:
                        .cancellationAction
                ) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                }
            }
        }
        .alert(error: $error) { _ in
            Button("OK") {}
        } message: { error in
            if let recoverySuggestion = error.recoverySuggestion {
                Text(recoverySuggestion)
            }
        }
    }

    private func save() {
        guard let amountInCents = draft.amountInCents
        else {
            return
        }

        do {
            try transactionService.create(
                type: draft.type,
                amountInCents:
                    amountInCents,
                note: draft.note,
                occurredOn:
                    draft.occurredOn,
                categoryId:
                    draft.categoryId,
                subcategoryId:
                    draft.subcategoryId,
                tags: draft.tags
            )

            dismiss()
        } catch {
            self.error =
                error as? TransactionServiceError
                ?? .couldNotCreate
        }
    }
}
