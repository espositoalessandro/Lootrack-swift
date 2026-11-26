import Foundation

struct DashboardActivity {
    struct Totals {
        var income = 0
        var expenses = 0
        var net: Int { income - expenses }
    }

    struct CategorySpending: Identifiable {
        let id: UUID?
        let name: String?
        let currentCents: Int
        let averageCents: Int
    }

    let currentMonth: Date
    let firstMonth: Date
    let lastMonth: Date
    let totals: Totals

    var loggedMonthCount: Int { monthlyTotals.count }
    var averageIncome: Int { monthlyAverage(totals.income) }
    var averageExpenses: Int { monthlyAverage(totals.expenses) }
    var averageNet: Int { monthlyAverage(totals.net) }

    private let calendar: Calendar
    private let categoryNames: [UUID: String]
    private let monthlyTotals: [Date: Totals]
    private let monthlySpending: [Date: [UUID?: Int]]
    private let spendingTotalsByCategory: [UUID?: Int]

    init(transactions: [Transaction], categories: [Category], now: Date = TransactionDate.today()) {
        let calendar = TransactionDate.calendar
        let currentMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let categoryNames = Dictionary(uniqueKeysWithValues: categories.filter { $0.deletedAt == nil }.map { ($0.id, $0.name) })
        var totals = Totals()
        var monthlyTotals: [Date: Totals] = [:]
        var monthlySpending: [Date: [UUID?: Int]] = [:]
        var spendingTotalsByCategory: [UUID?: Int] = [:]

        for transaction in transactions where transaction.deletedAt == nil {
            guard let month = calendar.dateInterval(of: .month, for: transaction.occurredOn)?.start else { continue }

            let amount = transaction.amountInCents

            switch transaction.type {
            case .income:
                totals.income += amount
                monthlyTotals[month, default: Totals()].income += amount
            case .expense:
                let categoryID = transaction.categoryId.flatMap { categoryNames[$0] == nil ? nil : $0 }
                totals.expenses += amount
                monthlyTotals[month, default: Totals()].expenses += amount
                monthlySpending[month, default: [:]][categoryID, default: 0] += amount
                spendingTotalsByCategory[categoryID, default: 0] += amount
            }
        }

        self.calendar = calendar
        self.currentMonth = currentMonth
        firstMonth = min(monthlyTotals.keys.min() ?? currentMonth, currentMonth)
        lastMonth = max(monthlyTotals.keys.max() ?? currentMonth, currentMonth)
        self.totals = totals
        self.categoryNames = categoryNames
        self.monthlyTotals = monthlyTotals
        self.monthlySpending = monthlySpending
        self.spendingTotalsByCategory = spendingTotalsByCategory
    }

    func totals(for month: Date) -> Totals {
        monthlyTotals[month] ?? Totals()
    }

    func hasTransactions(in month: Date) -> Bool {
        monthlyTotals[month] != nil
    }

    var trendMonths: [Date] {
        let monthSpan = calendar.dateComponents([.month], from: firstMonth, to: lastMonth).month ?? 0
        return (0 ... monthSpan).compactMap { calendar.date(byAdding: .month, value: $0, to: firstMonth) }
    }

    func spendingByCategory(in month: Date) -> [CategorySpending] {
        let currentSpending = monthlySpending[month] ?? [:]
        return spendingTotalsByCategory.map { id, cents in
            CategorySpending(id: id,
                             name: id.flatMap { categoryNames[$0] },
                             currentCents: currentSpending[id] ?? 0,
                             averageCents: monthlyAverage(cents))
        }
        .sorted { lhs, rhs in
            if lhs.currentCents != rhs.currentCents { return lhs.currentCents > rhs.currentCents }
            if lhs.averageCents != rhs.averageCents { return lhs.averageCents > rhs.averageCents }
            let nameOrder = (lhs.name ?? "").localizedStandardCompare(rhs.name ?? "")
            if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
            return (lhs.id?.uuidString ?? "") < (rhs.id?.uuidString ?? "")
        }
    }

    private func monthlyAverage(_ cents: Int) -> Int {
        guard loggedMonthCount > 0 else { return 0 }

        let (quotient, remainder) = cents.quotientAndRemainder(dividingBy: loggedMonthCount)
        return abs(remainder) * 2 < loggedMonthCount ? quotient : quotient + remainder.signum()
    }
}
