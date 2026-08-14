import SwiftUI
import SwiftData

struct TransactionRow: View {
    let transaction: Transaction
    
    @Query(CategoryQueries.activeByName)
    private var categories: [Category]
    
    private var category: Category? {
        guard let categoryId = transaction.categoryId else { return nil}
        return categories.first(where: { $0.id == categoryId })
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(transaction.note)
                    .bold()
                
                Text(category != nil ? category!.name : "Uncategorized")
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(((transaction.amountInCents)/100).formatted(.currency(code: "EUR")))
                .bold()
                .foregroundStyle(transaction.type == .expense ? .red : .green)

        }
    }
}

