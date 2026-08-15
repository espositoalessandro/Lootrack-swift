import SwiftUI
import SwiftData

struct TransactionRow: View {
    let transaction: Transaction
    let categoryName: String?
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(transaction.note)
                    .bold()
                
                Text(categoryName != nil ? categoryName! : "Uncategorized")
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text((Double(transaction.amountInCents)/100).formatted(.currency(code: "EUR")))
                .bold()
                .foregroundStyle(transaction.type == .expense ? .red : .green)

        }
    }
}

    