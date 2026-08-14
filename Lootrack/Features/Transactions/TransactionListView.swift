
import SwiftUI
import SwiftData


struct TransactionListView: View {
    @State private var showingAddTransaction = false
    @State private var editingTransaction: Transaction?
    
    @Environment(TransactionService.self)
    private var transactionService
    
    @Query(TransactionQueries.activeByMostRecent)
    private var transactions: [Transaction]
    
    var body: some View {
        List {
            ForEach(transactions) { transaction in
                TransactionRow(transaction: transaction)
                    .swipeActions(edge: .trailing) {
                        Button(
                            "Delete",
                            systemImage: "trash",
                            role: .destructive
                        ) {
                            do {
                                try transactionService.delete(transaction)
                            } catch {
                                print("FAILED TO DELETE TRANSACTION:", error)
                            }
                        };
                        Button("Edit", systemImage: "pencil") {
                            editingTransaction = transaction
                        }
                    }
                    .swipeActions (edge: .leading, allowsFullSwipe: true){
                        Button("Edit", systemImage: "pencil") {
                            editingTransaction = transaction
                        }
                    }
            }
        }
        .navigationTitle("Transactions")
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
            AddTransactionView()
        }
        .sheet(item: $editingTransaction) { transaction in
            EditTransactionView(transaction: transaction)
        }
    }
}
