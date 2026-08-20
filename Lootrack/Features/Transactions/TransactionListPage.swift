import SwiftData
import SwiftUI

private enum TransactionScrollTarget: Hashable {
    case top
    case monthHeader(Date)
    case day(Date, month: Date)
    case transaction(UUID, month: Date)
}

struct TransactionListView: View {
    @State
    private var editingTransaction: Transaction?

    @State
    private var showingAddTransaction = false

    @State
    private var selectedFilter: TransactionListFilter = .all

    @State
    private var searchQuery = ""

    @State
    private var scrolledTarget: TransactionScrollTarget?

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

    @Query(SubcategoryQueries.activeByName)
    private var subcategories: [Subcategory]

    private var categoryNamesById: [UUID: String] {
        Dictionary(uniqueKeysWithValues:
            categories.map { category in
                (category.id,
                 category.name)
            })
    }

    private var subcategoryNamesById: [UUID: String] {
        Dictionary(uniqueKeysWithValues:
            subcategories.map { subcategory in
                (subcategory.id,
                 subcategory.name)
            })
    }

    private var filteredTransactions: [Transaction] {
        let normalizedSearch =
            searchQuery
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

        return transactions.filter { transaction in
            guard matchesFilter(transaction) else {
                return false
            }

            guard !normalizedSearch.isEmpty else {
                return true
            }

            return searchableText(for: transaction)
                .contains(normalizedSearch)
        }
    }

    private var transactionGroups: [TransactionMonthGroup] {
        TransactionListGrouping.groups(from: filteredTransactions)
    }

    private var toolbarMonth: Date? {
        guard let scrolledTarget else {
            return nil
        }

        switch scrolledTarget {
        case .top:
            return nil

        case let .monthHeader(month):
            if month == transactionGroups.first?.date {
                return nil
            }

            return month

        case let .day(_, month):
            return month

        case let .transaction(_, month):
            return month
        }
    }

    private var showsAddTransactionFAB: Bool {
        guard let scrolledTarget else {
            return true
        }

        return scrolledTarget == .top
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading,
                       spacing: 0)
            {
                filterPicker
                    .id(TransactionScrollTarget.top)

                ForEach(transactionGroups) { month in
                    monthHeader(month)
                        .id(TransactionScrollTarget
                            .monthHeader(month.date))

                    ForEach(month.days) { day in
                        dayHeader(day,
                                  isFirst:
                                  day.id
                                      == month.days.first?.id)
                            .id(TransactionScrollTarget.day(day.date,
                                                            month: month.date))

                        ForEach(day.transactions) { transaction in
                            transactionRow(transaction)
                                .padding(.bottom,
                                         8)
                                .id(TransactionScrollTarget
                                    .transaction(transaction.id,
                                                 month: month.date))
                        }
                    }
                }
            }
            .scrollTargetLayout()
            .padding(.bottom,
                     16)
        }
        .refreshable {
            await syncCoordinator.synchronize()
        }
        .scrollPosition(id: $scrolledTarget,
                        anchor: .top)
        .swipeActionsContainer()
        .background(Color(uiColor: .systemGroupedBackground))
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Transactions")
        .toolbar {
            if let toolbarMonth {
                ToolbarItem(placement: .title) {
                    Text(toolbarMonth.formatted(.dateTime
                            .month(.wide)
                            .year()))
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button("Add",
                       systemImage: "plus")
                {
                    showingAddTransaction = true
                }
            }
        }
        .searchable(text: $searchQuery,
                    prompt: "Search transactions")
        .overlay(alignment: .bottom) {
            if showsAddTransactionFAB {
                addTransactionFAB
                    .padding(.bottom,
                             18)
                    .transition(.scale(scale: 0.8,
                                       anchor: .bottom)
                            .combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2),
                   value: showsAddTransactionFAB)
        .sheet(isPresented: $showingAddTransaction) {
            AddTransactionView()
        }
        .sheet(item: $editingTransaction) { transaction in
            EditTransactionView(transaction: transaction)
        }
    }

    // MARK: - Add

    private var addTransactionFAB: some View {
        Button {
            showingAddTransaction = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .frame(width: 58,
                       height: 58)
        }
        .buttonStyle(.glassProminent)
        .accessibilityLabel("Add Transaction")
    }

    // MARK: - Filter

    private var filterPicker: some View {
        Picker("Transaction type",
               selection: $selectedFilter)
        {
            ForEach(TransactionListFilter.allCases,
                    id: \.self)
            { filter in
                Text(filter.label)
                    .tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal,
                 16)
        .padding(.top,
                 8)
        .padding(.bottom,
                 10)
    }

    private func matchesFilter(_ transaction: Transaction) -> Bool {
        switch selectedFilter {
        case .all:
            true

        case .expense:
            transaction.type == .expense

        case .income:
            transaction.type == .income
        }
    }

    // MARK: - Search

    private func searchableText(for transaction: Transaction) -> String {
        let categoryName =
            transaction.categoryId
                .flatMap {
                    categoryNamesById[$0]
                }
                ?? String(localized: "Uncategorized")

        let subcategoryName =
            transaction.subcategoryId
                .flatMap {
                    subcategoryNamesById[$0]
                }
                ?? ""

        let tags =
            transaction.tags.joined(separator: " ")

        return [transaction.note,
                categoryName,
                subcategoryName,
                tags,
                transaction.type == .expense
                    ? "expense"
                    : "income"]
            .joined(separator: " ")
            .lowercased()
    }

    // MARK: - Headers

    private func monthHeader(_ month: TransactionMonthGroup) -> some View {
        Text(month.date.formatted(.dateTime
                .month(.wide)
                .year()))
            .font(.title2.bold())
            .foregroundStyle(.primary)
            .padding(.horizontal,
                     32)
            .padding(.top,
                     18)
            .padding(.bottom,
                     18)
    }

    private func dayHeader(_ day: TransactionDayGroup,
                           isFirst: Bool) -> some View
    {
        Text(day.date.formatted(.dateTime
                .weekday(.wide)
                .day()
                .month(.abbreviated)))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal,
                     32)
            .padding(.top,
                     isFirst ? 0 : 14)
            .padding(.bottom,
                     10)
    }

    // MARK: - Rows

    private func transactionRow(_ transaction: Transaction) -> some View {
        TransactionRow(transaction: transaction,
                       categoryName:
                       transaction.categoryId
                           .flatMap {
                               categoryNamesById[$0]
                           },
                       subcategoryName:
                       transaction.subcategoryId
                           .flatMap {
                               subcategoryNamesById[$0]
                           },
                       onEdit: {
                           editingTransaction =
                               transaction
                       },
                       onDelete: {
                           delete(transaction)
                       })
    }

    // MARK: - Delete

    private func delete(_ transaction: Transaction) {
        do {
            try transactionService.delete(transaction)

            registerUndo(for: transaction)
        } catch {
            print("FAILED TO DELETE TRANSACTION:",
                  error)
        }
    }

    private func registerUndo(for transaction: Transaction) {
        guard let undoManager else {
            return
        }

        undoManager.removeAllActions(withTarget: transactionService)

        undoManager.registerUndo(withTarget: transactionService) { service in
            do {
                try service.restore(transaction)
            } catch {
                print("FAILED TO UNDO TRANSACTION DELETE:",
                      error)
            }
        }

        undoManager.setActionName(String(localized:
            "Delete Transaction"))
    }
}
