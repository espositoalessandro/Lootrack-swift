import SwiftData
import SwiftUI

private enum TransactionListFilter: CaseIterable {
    case all
    case expense
    case income

    var label: String {
        switch self {
        case .all:
            return String(localized: "All")
        case .expense:
            return String(localized: "Expenses")
        case .income:
            return String(localized: "Income")
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
    @State private var editingTransaction: Transaction?

    @State private var selectedFilter: TransactionListFilter = .all
    @State private var searchQuery = ""

    @State private var currentMonth: Date?

    @Environment(TransactionService.self)
    private var transactionService

    @Environment(\.undoManager)
    private var undoManager

    @Environment(SyncCoordinator.self)
    private var syncCoordinator
    
    @Query(TransactionQueries.activeByMostRecent)
    private var transactions: [Transaction]

    @Query(CategoryQueries.activeByName)
    private var categories: [Category]

    private var categoryNamesById: [UUID: String] {
        Dictionary(
            uniqueKeysWithValues: categories.map { category in
                (category.id, category.name)
            }
        )
    }

    private var filteredTransactions: [Transaction] {
        let normalizedSearch =
            searchQuery
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return transactions.filter { transaction in
            let matchesFilter =
                switch selectedFilter {
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

            let categoryName =
                transaction.categoryId
                .flatMap { categoryNamesById[$0] }
                ?? String(localized: "Uncategorized")

            let searchableText = [
                transaction.note,
                categoryName,
                transaction.type == .expense ? "expense" : "income",
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

        return
            transactionsByMonth
            .map { monthDate, transactions in
                let transactionsByDay = Dictionary(
                    grouping: transactions
                ) { transaction in
                    calendar.startOfDay(
                        for: transaction.occurredOn
                    )
                }

                let days =
                    transactionsByDay
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

    private func monthStart(for date: Date) -> Date {
        Calendar.current.dateInterval(
            of: .month,
            for: date
        )!.start
    }

    private func newerMonth(than month: Date) -> Date? {
        guard
            let index = transactionGroups.firstIndex(
                where: { $0.date == month }
            ),
            index > 0
        else {
            return nil
        }

        return transactionGroups[index - 1].date
    }

    var body: some View {
        List {
            Picker(
                "Transaction type",
                selection: $selectedFilter
            ) {
                ForEach(
                    TransactionListFilter.allCases,
                    id: \.self
                ) { filter in
                    Text(filter.label)
                        .tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .listRowInsets(
                EdgeInsets(
                    top: 8,
                    leading: 0,
                    bottom: 8,
                    trailing: 0
                )
            )
            .listRowBackground(
                Color(uiColor: .systemGroupedBackground)
            )
            .listRowSeparator(.hidden)

            ForEach(transactionGroups) { month in
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
                                    delete(transaction)
                                }
                                Button(
                                    "Edit",
                                    systemImage: "pencil"
                                ) {
                                    editingTransaction = transaction
                                }
                                .tint(.blue)
                            }
                            .swipeActions(
                                edge: .leading,
                                allowsFullSwipe: true
                            ) {
                                Button(
                                    "Edit",
                                    systemImage: "pencil"
                                ) {
                                    editingTransaction = transaction
                                }
                                .tint(.blue)
                            }
                            .onGeometryChange(
                                for: Bool.self
                            ) { proxy in
                                let frame = proxy.frame(
                                    in: .scrollView
                                )

                                return
                                    frame.minY <= 0
                                    && frame.maxY > 0
                            } action: { isCrossingTop in
                                guard
                                    isCrossingTop,
                                    currentMonth != nil
                                else {
                                    return
                                }

                                currentMonth = monthStart(
                                    for: transaction.occurredOn
                                )
                            }
                        }
                    } header: {
                        VStack(
                            alignment: .leading,
                            spacing: 20
                        ) {
                            if day.id == month.days.first?.id {
                                Text(
                                    month.date.formatted(
                                        .dateTime
                                            .month(.wide)
                                            .year()
                                    )
                                )
                                .font(.title2.bold())
                                .foregroundStyle(.primary)
                                .onGeometryChange(
                                    for: Bool.self
                                ) { proxy in
                                    proxy.frame(
                                        in: .scrollView
                                    ).maxY <= 0
                                } action: { isPastTop in
                                    if isPastTop {
                                        currentMonth = month.date
                                    } else if currentMonth == month.date {
                                        currentMonth = newerMonth(
                                            than: month.date
                                        )
                                    }
                                }
                            }

                            Text(
                                day.date.formatted(
                                    .dateTime
                                        .weekday(.wide)
                                        .day()
                                        .month(.abbreviated)
                                )
                            )
                            .font(
                                .subheadline.weight(.semibold)
                            )
                            .foregroundStyle(.secondary)
                            .onGeometryChange(
                                for: Bool.self
                            ) { proxy in
                                let frame = proxy.frame(
                                    in: .scrollView
                                )

                                return
                                    frame.minY <= 0
                                    && frame.maxY > 0
                            } action: { isCrossingTop in
                                guard
                                    isCrossingTop,
                                    currentMonth != nil
                                else {
                                    return
                                }

                                currentMonth = monthStart(
                                    for: day.date
                                )
                            }
                        }
                        .textCase(nil)
                    }
                }
            }
        }
        .refreshable {
            await syncCoordinator.synchronize()
        }
        .listSectionSpacing(12)
        .navigationTitle("Transactions")
        .toolbar {
            if let currentMonth {
                ToolbarItem(placement: .title) {
                    Text(
                        currentMonth.formatted(
                            .dateTime
                                .month(.wide)
                                .year()
                        )
                    )
                }
            }
        }
        .searchable(
            text: $searchQuery,
            prompt: "Search transactions"
        )
        .sheet(
            item: $editingTransaction
        ) { transaction in
            EditTransactionView(
                transaction: transaction
            )
        }
    }

    private func delete(
        _ transaction: Transaction
    ) {
        do {
            try transactionService.delete(
                transaction
            )
            registerUndo(for: transaction)
        } catch {
            print(
                "FAILED TO DELETE TRANSACTION:",
                error
            )
        }
    }

    private func registerUndo(
        for transaction: Transaction
    ) {
        guard let undoManager else {
            return
        }

        /*
         * Only the latest accidental deletion
         * remains undoable.
         */
        undoManager.removeAllActions(
            withTarget: transactionService
        )

        undoManager.registerUndo(
            withTarget: transactionService
        ) { service in
            do {
                try service.restore(
                    transaction
                )
            } catch {
                print(
                    "FAILED TO UNDO TRANSACTION DELETE:",
                    error
                )
            }
        }

        undoManager.setActionName(
            String(
                localized: "Delete Transaction"
            )
        )
    }
}
