import Foundation

struct DashboardActivity {
    struct Totals {
        var income = 0
        var expenses = 0
        var net: Int { income - expenses }
    }

    struct CategoryAmount: Identifiable {
        let id: UUID?
        let name: String?
        let cents: Int
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
    private let categoryTotals: [TransactionType: [UUID?: Int]]

    init(transactions: [Transaction], categories: [Category], now: Date = TransactionDate.today()) {
        let calendar = TransactionDate.calendar
        let currentMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let categoryNames = Dictionary(uniqueKeysWithValues: categories.filter { $0.deletedAt == nil }.map { ($0.id, $0.name) })
        var totals = Totals()
        var monthlyTotals: [Date: Totals] = [:]
        var monthlySpending: [Date: [UUID?: Int]] = [:]
        var categoryTotals: [TransactionType: [UUID?: Int]] = [:]

        for transaction in transactions where transaction.deletedAt == nil {
            guard let month = calendar.dateInterval(of: .month, for: transaction.occurredOn)?.start else { continue }

            let categoryID = transaction.categoryId.flatMap { categoryNames[$0] == nil ? nil : $0 }
            let amount = transaction.amountInCents
            categoryTotals[transaction.type, default: [:]][categoryID, default: 0] += amount

            switch transaction.type {
            case .income:
                totals.income += amount
                monthlyTotals[month, default: Totals()].income += amount
            case .expense:
                totals.expenses += amount
                monthlyTotals[month, default: Totals()].expenses += amount
                monthlySpending[month, default: [:]][categoryID, default: 0] += amount
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
        self.categoryTotals = categoryTotals
    }

    func totals(for month: Date) -> Totals {
        monthlyTotals[month] ?? Totals()
    }

    func hasTransactions(in month: Date) -> Bool {
        monthlyTotals[month] != nil
    }

    func month(byAdding offset: Int, to month: Date) -> Date? {
        guard let date = calendar.date(byAdding: .month, value: offset, to: month),
              (firstMonth ... lastMonth).contains(date)
        else { return nil }

        return date
    }

    var trendMonths: [Date] {
        let monthSpan = calendar.dateComponents([.month], from: firstMonth, to: lastMonth).month ?? 0
        return (0 ... monthSpan).compactMap { month(byAdding: $0, to: firstMonth) }
    }

    func spendingByCategory(in month: Date) -> [CategoryAmount] {
        categoryAmounts(monthlySpending[month] ?? [:])
    }

    func averageByCategory(for type: TransactionType) -> [CategoryAmount] {
        categoryAmounts(categoryTotals[type]?.mapValues(monthlyAverage) ?? [:])
    }

    private func monthlyAverage(_ cents: Int) -> Int {
        guard loggedMonthCount > 0 else { return 0 }

        let (quotient, remainder) = cents.quotientAndRemainder(dividingBy: loggedMonthCount)
        return abs(remainder) * 2 < loggedMonthCount ? quotient : quotient + remainder.signum()
    }

    private func categoryAmounts(_ amounts: [UUID?: Int]) -> [CategoryAmount] {
        amounts.map { id, cents in
            CategoryAmount(id: id, name: id.flatMap { categoryNames[$0] }, cents: cents)
        }
        .sorted { lhs, rhs in
            if lhs.cents != rhs.cents { return lhs.cents > rhs.cents }
            let nameOrder = (lhs.name ?? "").localizedStandardCompare(rhs.name ?? "")
            if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
            return (lhs.id?.uuidString ?? "") < (rhs.id?.uuidString ?? "")
        }
    }
}
