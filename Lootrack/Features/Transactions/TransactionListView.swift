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

private struct TransactionDayGroup: Identifiable {
    let date: Date
    let transactions: [Transaction]
    
    var id: Date { date }
}

private struct TransactionMonthGroup: Identifiable {
    let date: Date
    let days: [TransactionDayGroup]
    
    var id: Date { date }
}

struct TransactionListView: View {
    @State private var showingAddTransaction = false
    @State private var editingTransaction: Transaction?
    @State private var selectedFilter: TransactionListFilter = .all
    @State private var searchQuery = ""
    
    @Environment(TransactionService.self)
    private var transactionService
    
    @Query(TransactionQueries.activeByMostRecent)
    private var transactions: [Transaction]
    private var filteredTransactions: [Transaction] {
        let normalizedSearch = searchQuery
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        
        return transactions.filter { transaction in
            let matchesFilter = switch selectedFilter {
            case .all:
                true
                
            case .expense:
                transaction.type == .expense
                
            case .income:
                transaction.type == .income
            }
            
            guard matchesFilter else {
                return false
            }
            
            guard !normalizedSearch.isEmpty else {
                return true
            }
            
            let categoryName = transaction.categoryId
                .flatMap { categoryNamesById[$0] }
            ?? "Uncategorized"
            
            let searchableText = [
                transaction.note,
                categoryName,
                transaction.type == .expense ? "expense" : "income"
            ]
                .joined(separator: " ")
                .lowercased()
            
            return searchableText.contains(normalizedSearch)
        }
    }
    
    private var transactionGroups: [TransactionMonthGroup] {
        let calendar = Calendar.current
        
        let transactionsByMonth = Dictionary(
            grouping: filteredTransactions
        ) { transaction in
            calendar.dateInterval(
                of: .month,
                for: transaction.occurredOn
            )!.start
        }
        
        return transactionsByMonth
            .map { monthDate, transactions in
                let transactionsByDay = Dictionary(
                    grouping: transactions
                ) { transaction in
                    calendar.startOfDay(
                        for: transaction.occurredOn
                    )
                }
                
                let days = transactionsByDay
                    .map { dayDate, transactions in
                        TransactionDayGroup(
                            date: dayDate,
                            transactions: transactions
                        )
                    }
                    .sorted { $0.date > $1.date }
                
                return TransactionMonthGroup(
                    date: monthDate,
                    days: days
                )
            }
            .sorted { $0.date > $1.date }
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
            ForEach(transactionGroups) { month in
                Section {
                    ForEach(month.days) { day in
                        Section {
                            ForEach(day.transactions) { transaction in
                                TransactionRow(
                                    transaction: transaction,
                                    categoryName: transaction.categoryId.flatMap {
                                        categoryNamesById[$0]
                                    }
                                )
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
                        } header: {
                            Text(
                                day.date.formatted(
                                    .dateTime
                                        .weekday(.wide)
                                        .day()
                                        .month(.abbreviated)
                                )
                            )
                        }
                    }
                } header: {
                    Text(
                        month.date.formatted(
                            .dateTime
                                .month(.wide)
                                .year()
                        )
                    )
                }
            }
        }
        .navigationTitle("Transactions")
        .safeAreaInset(edge: .bottom) {
            Color.clear
                .frame(height: 80)
        }
        .searchable(
            text: $searchQuery,
            prompt: "Search transactions"
        )
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
