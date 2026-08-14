import SwiftUI

struct TransactionForm: View {
    @Binding var note: String
    @Binding var amount: String
    @Binding var type: TransactionType

    var body: some View {
        Form {
            Section("Transaction") {
                TextField("Description", text: $note)

                TextField("Amount", text: $amount)
                    .keyboardType(.decimalPad)

                Picker("Type", selection: $type) {
                    Text("Expense")
                        .tag(TransactionType.expense)

                    Text("Income")
                        .tag(TransactionType.income)
                }
            }
        }
    }
}
