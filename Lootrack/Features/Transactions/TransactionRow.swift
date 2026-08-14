import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(transaction.note)
                
                Text(transaction.type == .expense ? "Expense" : "Income")
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text("\(transaction.amountInCents)")
        }
    }
}

