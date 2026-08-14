import SwiftUI

struct EditTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    
    let transaction: Transaction
    
    @State private var draft: TransactionDraft
    
    
    init(transaction: Transaction) {
        self.transaction = transaction
        _draft = State(
            initialValue: TransactionDraft(transaction: transaction)
        )
    }
    
    var body: some View {
        NavigationStack {
            TransactionForm(draft: $draft)
            .navigationTitle("Edit Transaction")
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

        transaction.note = draft.note
        transaction.amountInCents = amountInCents
        transaction.type = draft.type
        transaction.occurredOn = draft.occurredOn
        transaction.updatedAt = .now
        transaction.categoryId = draft.categoryId
    
        dismiss()
    }    
}
