import SwiftUI

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (Transaction) -> Void
    
    @State private var description = ""
    @State private var amount = ""
    @State private var type: TransactionType = .expense

    var body: some View {
        NavigationStack {
            Form {
                Section("Transaction") {
                    TextField("Description", text: $description)

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
        guard let amountInCents else {
            return
        }

        let transaction = Transaction(
            id: UUID(),
            type: type,
            amountInCents: amountInCents,
            note: description,
            occurredOn: Date()
        )

        onSave(transaction)
        dismiss()
    }
    
    private var amountInCents: Int? {
        let normalized = amount.replacingOccurrences(of: ",", with: ".")

        guard let decimal = Decimal(string: normalized) else {
            return nil
        }

        return NSDecimalNumber(decimal: decimal * 100).intValue
    }
}

