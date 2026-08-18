import SwiftUI

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss

    @Environment(TransactionService.self)
    private var transactionService

    @State private var draft = TransactionDraft()

    var body: some View {
        NavigationStack {
            TransactionForm(
                draft: $draft,
                autoSelectCategoryWithAI: true,
                quickAmountEntry: true
            )
            .navigationTitle("New Transaction")
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
                }
            }
        }
    }

    private func save() {
        guard let amountInCents = draft.amountInCents else {
            return
        }

        do {
            try transactionService.create(
                type: draft.type,
                amountInCents: amountInCents,
                note: draft.note,
                occurredOn: draft.occurredOn,
                categoryId: draft.categoryId
            )

            dismiss()
        } catch {
            print("FAILED TO CREATE TRANSACTION:", error)
        }
    }
}
