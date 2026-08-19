import SwiftUI

struct EditTransactionView: View {
    @Environment(\.dismiss)
    private var dismiss

    let transaction: Transaction

    @State
    private var draft: TransactionDraft

    @Environment(TransactionService.self)
    private var transactionService

    init(transaction: Transaction) {
        self.transaction = transaction

        _draft = State(
            initialValue:
                TransactionDraft(
                    transaction:
                        transaction
                )
        )
    }

    var body: some View {
        NavigationStack {
            TransactionForm(
                draft: $draft
            )
            .navigationTitle(
                "Edit Transaction"
            )
            .toolbar {
                ToolbarItem(
                    placement:
                        .cancellationAction
                ) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(
                    placement:
                        .confirmationAction
                ) {
                    Button("Save") {
                        save()
                    }
                }
            }
        }
    }

    private func save() {
        guard
            let amountInCents =
                draft.amountInCents
        else {
            return
        }

        do {
            try transactionService.update(
                transaction,
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
            print(
                "FAILED TO UPDATE TRANSACTION:",
                error
            )
        }
    }
}
