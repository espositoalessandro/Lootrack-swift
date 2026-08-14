import SwiftUI

struct EditTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    
    let transaction: Transaction
    
    @State private var note: String
    @State private var amount: String
    @State private var type: TransactionType
    
    
    init(transaction: Transaction) {
        self.transaction = transaction

        _note = State(initialValue: transaction.note)

        _amount = State(
            initialValue: NSDecimalNumber(
                value: transaction.amountInCents
            )
            .dividing(by: 100)
            .stringValue
        )

        _type = State(initialValue: transaction.type)
    }
    
    var body: some View {
        NavigationStack {
            TransactionForm(
                note: $note,
                amount: $amount,
                type: $type
            )
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
        guard let amountInCents else {
            return
        }

        transaction.note = note
        transaction.amountInCents = amountInCents
        transaction.type = type

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
