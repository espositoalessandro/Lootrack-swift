import Foundation

nonisolated struct WidgetValueEvaluator {
    func evaluate(_ value: WidgetValue, transactions: [Transaction], calendar: Calendar = .current, now: Date = .now) -> Int {
        let transactions = transactions.filter { matches($0, filter: value.filter, calendar: calendar, now: now) }
        return aggregate(transactions, using: value.aggregation)
    }
    
    func matches(_ transaction: Transaction, filter: WidgetFilter, calendar: Calendar = .current, now: Date = .now) -> Bool {
        guard transaction.deletedAt == nil else {
            return false
        }
        
        if let transactionType = filter.transactionType, transaction.type != transactionType {
            return false
        }
        
        if let minimumAmountInCents = filter.minimumAmountInCents, transaction.amountInCents < minimumAmountInCents {
            return false
        }
        
        if let maximumAmountInCents = filter.maximumAmountInCents, transaction.amountInCents > maximumAmountInCents {
            return false
        }
        
        if let categoryId = filter.categoryId, transaction.categoryId != categoryId {
            return false
        }
        
        if let subcategoryId = filter.subcategoryId, transaction.subcategoryId != subcategoryId {
            return false
        }
        
        if let tag = filter.tag, !transaction.tags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) {
            return false
        }
        
        return contains(transaction.occurredOn, in: filter.timeRange, calendar: calendar, now: now)
    }
    
    private func aggregate(_ transactions: [Transaction], using aggregation: WidgetAggregation) -> Int {
        let amounts = transactions.map(\.amountInCents)
        
        guard !amounts.isEmpty else {
            return 0
        }
        
        switch aggregation {
        case .total:
            return amounts.reduce(0, +)
            
        case .mean:
            return Int((Double(amounts.reduce(0, +)) / Double(amounts.count)).rounded())
            
        case .median:
            let sortedAmounts = amounts.sorted()
            let middle = sortedAmounts.count / 2
            
            if sortedAmounts.count.isMultiple(of: 2) {
                return Int(((Double(sortedAmounts[middle - 1]) + Double(sortedAmounts[middle])) / 2).rounded())
            }
            
            return sortedAmounts[middle]
            
        case .minimum:
            return amounts.min() ?? 0
            
        case .maximum:
            return amounts.max() ?? 0
        }
    }
    
    private func contains(_ date: Date, in range: WidgetTimeRange, calendar: Calendar, now: Date) -> Bool {
        switch range {
        case .allTime:
            return true
            
        case .currentWeek:
            return calendar.dateInterval(of: .weekOfYear, for: now)?.contains(date) == true
            
        case .currentMonth:
            return calendar.dateInterval(of: .month, for: now)?.contains(date) == true
            
        case .currentYear:
            return calendar.dateInterval(of: .year, for: now)?.contains(date) == true
            
        case .custom(let start, let end):
            let start = calendar.startOfDay(for: start)
            
            guard let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end)) else {
                return false
            }
            
            return date >= start && date < end
        }
    }
}
