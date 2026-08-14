import SwiftUI

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (Transaction) -> Void
    
    @State private var draft = TransactionDraft()

    var body: some View {
        NavigationStack {
            TransactionForm(draft: $draft)
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

        let transaction = Transaction(
            id: UUID(),
            createdAt: .now,
            updatedAt: .now,
            type: draft.type,
            amountInCents: amountInCents,
            note: draft.note,
            occurredOn: draft.occurredOn,
            categoryId: draft.categoryId
        )

        onSave(transaction)
        dismiss()
    }
}

