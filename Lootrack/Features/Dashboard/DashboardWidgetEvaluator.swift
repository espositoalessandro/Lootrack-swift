import Foundation

nonisolated struct DashboardWidgetChartPoint: Identifiable, Hashable, Sendable {
    let date: Date
    let valueInCents: Int

    var id: Date {
        date
    }
}

nonisolated enum DashboardWidgetResult: Hashable, Sendable {
    case numeric(Int)
    case chart([DashboardWidgetChartPoint])
}

nonisolated struct DashboardWidgetEvaluator {
    private let valueEvaluator = WidgetValueEvaluator()

    func evaluate(_ widget: DashboardWidgetDefinition, transactions: [Transaction], calendar: Calendar = .current, now: Date = .now) -> DashboardWidgetResult {
        switch widget.type {
        case .numeric:
            return .numeric(evaluateScalar(widget, transactions: transactions, calendar: calendar, now: now))

        case .chart:
            return .chart(evaluateChart(widget, transactions: transactions, calendar: calendar, now: now))
        }
    }

    private func evaluateScalar(_ widget: DashboardWidgetDefinition, transactions: [Transaction], calendar: Calendar, now: Date) -> Int {
        let primary = valueEvaluator.evaluate(widget.primaryValue, transactions: transactions, calendar: calendar, now: now)

        guard let operation = widget.operation, let secondaryValue = widget.secondaryValue else {
            return primary
        }

        let secondary = valueEvaluator.evaluate(secondaryValue, transactions: transactions, calendar: calendar, now: now)

        switch operation {
        case .add:
            return primary + secondary
        case .subtract:
            return primary - secondary
        }
    }

    private func evaluateChart(_ widget: DashboardWidgetDefinition, transactions: [Transaction], calendar: Calendar, now: Date) -> [DashboardWidgetChartPoint] {
        guard let grouping = widget.grouping else {
            return []
        }

        let candidates = transactions.filter { transaction in
            if valueEvaluator.matches(transaction, filter: widget.primaryValue.filter, calendar: calendar, now: now) {
                return true
            }

            if let secondaryValue = widget.secondaryValue {
                return valueEvaluator.matches(transaction, filter: secondaryValue.filter, calendar: calendar, now: now)
            }

            return false
        }

        let groups = Dictionary(grouping: candidates) { transaction in
            groupStart(for: transaction.occurredOn, grouping: grouping, calendar: calendar)
        }

        return groups.keys.sorted().map { date in
            DashboardWidgetChartPoint(
                date: date,
                valueInCents: evaluateScalar(widget, transactions: groups[date] ?? [], calendar: calendar, now: now)
            )
        }
    }

    private func groupStart(for date: Date, grouping: WidgetGrouping, calendar: Calendar) -> Date {
        switch grouping {
        case .day:
            return calendar.startOfDay(for: date)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        case .month:
            return calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
        case .year:
            return calendar.dateInterval(of: .year, for: date)?.start ?? calendar.startOfDay(for: date)
        }
    }
}
