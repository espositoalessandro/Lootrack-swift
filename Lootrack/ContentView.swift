import SwiftUI
import SwiftData


struct ContentView: View {
    @State private var showingAddTransaction = false
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.occurredOn, order: .reverse)
    private var transactions: [Transaction]
    
    
    var body: some View {
        List {
            ForEach(transactions) { transaction in
                TransactionRow(transaction: transaction)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear
                .frame(height: 80)
        }
        .overlay(alignment: .bottom) {
            Button {
                showingAddTransaction = true
            } label: {
                Label("Add transaction", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.glass)
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .sheet(isPresented: $showingAddTransaction) {
            AddTransactionView { transaction in
                modelContext.insert(transaction)
            }
        }
    }
}

#Preview {
    ContentView()
}
