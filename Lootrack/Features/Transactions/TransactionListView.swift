
import SwiftUI
import SwiftData


struct TransactionListView: View {
    @State private var showingAddTransaction = false
    @State private var editingTransaction: Transaction?
    
    @Environment(\.modelContext) private var modelContext
    
    @Query(TransactionQueries.activeByMostRecent)
    private var transactions: [Transaction]
    
    var body: some View {
        List {
            ForEach(transactions) { transaction in
                TransactionRow(transaction: transaction)
                    .onTapGesture {
                        editingTransaction = transaction
                    }
                    .swipeActions {
                        Button(
                            "Delete",
                            systemImage: "trash",
                            role: .destructive
                        ) {
                            transaction.deletedAt = .now
                            transaction.updatedAt = .now
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
            AddTransactionView { transaction in
                modelContext.insert(transaction)
                do {
                    try modelContext.save()
                } catch {
                    print("SWIFTDATA SAVE ERROR:", error)
                }
            }
        }
        .sheet(item: $editingTransaction) { transaction in
            EditTransactionView(transaction: transaction)
        }
    }
}
