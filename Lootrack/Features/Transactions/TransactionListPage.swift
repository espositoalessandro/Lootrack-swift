import SwiftData
import SwiftUI

struct TransactionListView: View {
    @State
    private var editingTransaction: Transaction?

    @State
    private var selectedFilter: TransactionListFilter = .all

    @State
    private var searchQuery = ""

    @State
    private var currentMonth: Date?

    @Environment(TransactionService.self)
    private var transactionService

    @Environment(\.undoManager)
    private var undoManager

    @Query(TransactionQueries.activeByMostRecent)
    private var transactions: [Transaction]

    @Query(CategoryQueries.activeByName)
    private var categories: [Category]

    @Query(SubcategoryQueries.activeByName)
    private var subcategories: [Subcategory]

    private var categoryNamesById: [UUID: String] {
        Dictionary(
            uniqueKeysWithValues:
                categories.map { category in
                    (
                        category.id,
                        category.name
                    )
                }
        )
    }

    private var subcategoryNamesById: [UUID: String] {
        Dictionary(
            uniqueKeysWithValues:
                subcategories.map { subcategory in
                    (
                        subcategory.id,
                        subcategory.name
                    )
                }
        )
    }

    private var filteredTransactions: [Transaction] {
        let normalizedSearch =
            searchQuery
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased()

        return transactions.filter { transaction in
            guard matchesFilter(transaction) else {
                return false
            }

            guard !normalizedSearch.isEmpty else {
                return true
            }

            return searchableText(
                for: transaction
            )
            .contains(normalizedSearch)
        }
    }

    private var transactionGroups: [TransactionMonthGroup] {
        TransactionListGrouping.groups(
            from: filteredTransactions
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(
                alignment: .leading,
                spacing: 0
            ) {
                filterPicker

                ForEach(transactionGroups) { month in
                    monthHeader(month)

                    ForEach(month.days) { day in
                        dayHeader(
                            day,
                            isFirst:
                                day.id
                                == month.days.first?.id
                        )

                        ForEach(day.transactions) { transaction in
                            transactionRow(
                                transaction
                            )
                            .padding(
                                .bottom,
                                8
                            )
                        }
                    }
                }
            }
            .padding(
                .bottom,
                16
            )
        }
        .swipeActionsContainer()
        .background(
            Color(
                uiColor: .systemGroupedBackground
            )
        )
        .scrollDismissesKeyboard(
            .interactively
        )
        .navigationTitle(
            "Transactions"
        )
        .toolbar {
            if let currentMonth {
                ToolbarItem(
                    placement: .title
                ) {
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

    // MARK: - Filter

    private var filterPicker: some View {
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
        .padding(
            .horizontal,
            16
        )
        .padding(
            .top,
            8
        )
        .padding(
            .bottom,
            10
        )
    }

    private func matchesFilter(
        _ transaction: Transaction
    ) -> Bool {
        switch selectedFilter {
        case .all:
            return true

        case .expense:
            return transaction.type == .expense

        case .income:
            return transaction.type == .income
        }
    }

    // MARK: - Search

    private func searchableText(
        for transaction: Transaction
    ) -> String {
        let categoryName =
            transaction.categoryId
            .flatMap {
                categoryNamesById[$0]
            }
            ?? String(
                localized: "Uncategorized"
            )

        let subcategoryName =
            transaction.subcategoryId
            .flatMap {
                subcategoryNamesById[$0]
            }
            ?? ""

        let tags =
            transaction.tags.joined(
                separator: " "
            )

        return [
            transaction.note,
            categoryName,
            subcategoryName,
            tags,
            transaction.type == .expense
                ? "expense"
                : "income",
        ]
        .joined(separator: " ")
        .lowercased()
    }

    // MARK: - Headers

    private func monthHeader(
        _ month: TransactionMonthGroup
    ) -> some View {
        Text(
            month.date.formatted(
                .dateTime
                    .month(.wide)
                    .year()
            )
        )
        .font(
            .title2.bold()
        )
        .foregroundStyle(.primary)
        .padding(
            .horizontal,
            32
        )
        .padding(
            .top,
            18
        )
        .padding(
            .bottom,
            18
        )
        .onGeometryChange(
            for: Bool.self
        ) { proxy in
            proxy.frame(
                in: .scrollView
            ).maxY <= 0
        } action: { isPastTop in
            if isPastTop {
                currentMonth =
                    month.date
            } else if currentMonth == month.date {
                currentMonth =
                    newerMonth(
                        than: month.date
                    )
            }
        }
    }

    private func dayHeader(
        _ day: TransactionDayGroup,
        isFirst: Bool
    ) -> some View {
        Text(
            day.date.formatted(
                .dateTime
                    .weekday(.wide)
                    .day()
                    .month(.abbreviated)
            )
        )
        .font(
            .subheadline.weight(
                .semibold
            )
        )
        .foregroundStyle(.secondary)
        .padding(
            .horizontal,
            32
        )
        .padding(
            .top,
            isFirst ? 0 : 14
        )
        .padding(
            .bottom,
            10
        )
    }

    private func newerMonth(
        than month: Date
    ) -> Date? {
        guard
            let index =
                transactionGroups.firstIndex(
                    where: {
                        $0.date == month
                    }
                ),
            index > 0
        else {
            return nil
        }

        return
            transactionGroups[
                index - 1
            ].date
    }

    // MARK: - Rows

    private func transactionRow(
        _ transaction: Transaction
    ) -> some View {
        TransactionRow(
            transaction: transaction,
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
                delete(
                    transaction
                )
            }
        )
    }

    // MARK: - Delete

    private func delete(
        _ transaction: Transaction
    ) {
        do {
            try transactionService.delete(
                transaction
            )

            registerUndo(
                for: transaction
            )
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
                localized:
                    "Delete Transaction"
            )
        )
    }
}
