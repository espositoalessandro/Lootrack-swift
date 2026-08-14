import SwiftUI

struct TransactionForm: View {
    @Binding var draft: TransactionDraft

    var body: some View {
        Form {
            Section("Transaction") {
                TextField("Description", text: $draft.note)

                TextField("Amount", text: $draft.amount)
                    .keyboardType(.decimalPad)

                Picker("Type", selection: $draft.type) {
                    Text("Expense")
                        .tag(TransactionType.expense)

                    Text("Income")
                        .tag(TransactionType.income)
                }
            }
        }
    }
}
