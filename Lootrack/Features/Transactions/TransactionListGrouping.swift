import Foundation

enum TransactionListFilter: CaseIterable {
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

struct TransactionDayGroup: Identifiable {
    let date: Date
    let transactions: [Transaction]

    var id: Date {
        date
    }
}

struct TransactionMonthGroup: Identifiable {
    let date: Date
    let days: [TransactionDayGroup]

    var id: Date {
        date
    }
}

enum TransactionListGrouping {
    static func groups(
        from transactions: [Transaction]
    ) -> [TransactionMonthGroup] {
        let calendar = Calendar.current

        let transactionsByMonth = Dictionary(
            grouping: transactions
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
                            transactions: transactions.sorted {
                                $0.occurredOn > $1.occurredOn
                            }
                        )
                    }
                    .sorted {
                        $0.date > $1.date
                    }

                return TransactionMonthGroup(
                    date: monthDate,
                    days: days
                )
            }
            .sorted {
                $0.date > $1.date
            }
    }
}
