import SwiftUI
import SwiftData

private enum TransactionListFilter: CaseIterable {
    case all
    case expense
    case income

    var label: String {
        switch self {
        case .all:
            return "All"
        case .expense:
            return "Expenses"
        case .income:
            return "Income"
        }
    }
}

struct TransactionListView: View {
    @State private var showingAddTransaction = false
    @State private var editingTransaction: Transaction?
    @State private var selectedFilter: TransactionListFilter = .all
    
    
    @Environment(TransactionService.self)
    private var transactionService
    
    @Query(TransactionQueries.activeByMostRecent)
    private var transactions: [Transaction]
    private var filteredTransactions: [Transaction] {
        transactions.filter { transaction in
            switch selectedFilter {
            case .all:
                return true

            case .expense:
                return transaction.type == .expense

            case .income:
                return transaction.type == .income
            }
        }
    }
    
    @Query(CategoryQueries.activeByName)
    private var categories: [Category]
    
    private var categoryNamesById: [UUID: String] {
        Dictionary(
            uniqueKeysWithValues: categories.map { category in
                (category.id, category.name)
            }
        )
    }
    
    var body: some View {
        Picker("Transaction type", selection: $selectedFilter) {
            ForEach(TransactionListFilter.allCases, id: \.self) { filter in
                Text(filter.label)
                    .tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        List {
            ForEach(filteredTransactions) { transaction in
                TransactionRow(
                    transaction: transaction,
                    categoryName: transaction.categoryId.flatMap {
                        categoryNamesById[$0]
                    })
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
                    }.tint(.blue)
                }
                .swipeActions (edge: .leading, allowsFullSwipe: true){
                    Button("Edit", systemImage: "pencil") {
                        editingTransaction = transaction
                    }.tint(.blue)
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
