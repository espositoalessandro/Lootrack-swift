import Foundation

nonisolated enum DashboardWidgetType: String, Codable, CaseIterable, Hashable, Sendable {
    case numeric
    case chart
}

nonisolated enum DashboardWidgetWidth: Int, Codable, Hashable, Sendable {
    case single = 1
    case full = 2
}

nonisolated enum WidgetAggregation: String, Codable, CaseIterable, Hashable, Sendable {
    case total
    case mean
    case median
    case minimum
    case maximum
}

nonisolated enum WidgetOperation: String, Codable, CaseIterable, Hashable, Sendable {
    case add
    case subtract
}

nonisolated enum WidgetGrouping: String, Codable, CaseIterable, Hashable, Sendable {
    case day
    case week
    case month
    case year
}

nonisolated enum WidgetTimeRange: Codable, Hashable, Sendable {
    case allTime
    case currentWeek
    case currentMonth
    case currentYear
    case custom(start: Date, end: Date)
}

nonisolated struct WidgetFilter: Codable, Hashable, Sendable {
    var timeRange: WidgetTimeRange
    var transactionType: TransactionType?
    var minimumAmountInCents: Int?
    var maximumAmountInCents: Int?
    var categoryId: UUID?
    var subcategoryId: UUID?
    var tag: String?
    
    init(
        timeRange: WidgetTimeRange = .allTime,
        transactionType: TransactionType? = nil,
        minimumAmountInCents: Int? = nil,
        maximumAmountInCents: Int? = nil,
        categoryId: UUID? = nil,
        subcategoryId: UUID? = nil,
        tag: String? = nil
    ) {
        self.timeRange = timeRange
        self.transactionType = transactionType
        self.minimumAmountInCents = minimumAmountInCents
        self.maximumAmountInCents = maximumAmountInCents
        self.categoryId = categoryId
        self.subcategoryId = subcategoryId
        self.tag = tag
    }
}

nonisolated struct WidgetValue: Codable, Hashable, Sendable {
    var filter: WidgetFilter
    var aggregation: WidgetAggregation
    
    init(filter: WidgetFilter = WidgetFilter(), aggregation: WidgetAggregation = .total) {
        self.filter = filter
        self.aggregation = aggregation
    }
}

nonisolated struct DashboardWidgetDefinition: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    
    var title: String
    var type: DashboardWidgetType
    var primaryValue: WidgetValue
    var operation: WidgetOperation?
    var secondaryValue: WidgetValue?
    var grouping: WidgetGrouping?
    
    var width: DashboardWidgetWidth {
        switch type {
        case .numeric:
                .single
        case .chart:
                .full
        }
    }
    
    init(
        id: UUID = UUID(),
        title: String,
        type: DashboardWidgetType,
        primaryValue: WidgetValue,
        operation: WidgetOperation? = nil,
        secondaryValue: WidgetValue? = nil,
        grouping: WidgetGrouping? = nil
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.primaryValue = primaryValue
        self.operation = operation
        self.secondaryValue = secondaryValue
        self.grouping = grouping
    }
}

extension DashboardWidgetDefinition {
    static let samples: [DashboardWidgetDefinition] = [
        DashboardWidgetDefinition(
            title: "Net this month",
            type: .numeric,
            primaryValue: WidgetValue(filter: WidgetFilter(timeRange: .currentMonth, transactionType: .income)),
            operation: .subtract,
            secondaryValue: WidgetValue(filter: WidgetFilter(timeRange: .currentMonth, transactionType: .expense))
        ),
        DashboardWidgetDefinition(
            title: "Expenses",
            type: .numeric,
            primaryValue: WidgetValue(filter: WidgetFilter(timeRange: .currentMonth, transactionType: .expense))
        ),
        DashboardWidgetDefinition(
            title: "Monthly balance",
            type: .chart,
            primaryValue: WidgetValue(filter: WidgetFilter(timeRange: .currentYear, transactionType: .income)),
            operation: .subtract,
            secondaryValue: WidgetValue(filter: WidgetFilter(timeRange: .currentYear, transactionType: .expense)),
            grouping: .month
        ),
        DashboardWidgetDefinition(
            title: "Income",
            type: .numeric,
            primaryValue: WidgetValue(filter: WidgetFilter(timeRange: .currentMonth, transactionType: .income))
        ),
        DashboardWidgetDefinition(
            title: "Average expense",
            type: .numeric,
            primaryValue: WidgetValue(
                filter: WidgetFilter(timeRange: .currentMonth, transactionType: .expense),
                aggregation: .mean
            )
        ),
        DashboardWidgetDefinition(
            title: "Expense trend",
            type: .chart,
            primaryValue: WidgetValue(filter: WidgetFilter(timeRange: .currentYear, transactionType: .expense)),
            grouping: .month
        )
    ]
    
    static let librarySamples = samples + [
        DashboardWidgetDefinition(
            title: "Median expense",
            type: .numeric,
            primaryValue: WidgetValue(
                filter: WidgetFilter(timeRange: .currentMonth, transactionType: .expense),
                aggregation: .median
            )
        ),
        DashboardWidgetDefinition(
            title: "Largest expense",
            type: .numeric,
            primaryValue: WidgetValue(
                filter: WidgetFilter(timeRange: .currentMonth, transactionType: .expense),
                aggregation: .maximum
            )
        ),
        DashboardWidgetDefinition(
            title: "Weekly expenses",
            type: .chart,
            primaryValue: WidgetValue(filter: WidgetFilter(timeRange: .currentYear, transactionType: .expense)),
            grouping: .week
        )
    ]
    
    static func numericPlaceholder(index: Int) -> DashboardWidgetDefinition {
        DashboardWidgetDefinition(
            title: "Numeric widget \(index)",
            type: .numeric,
            primaryValue: WidgetValue(filter: WidgetFilter(timeRange: .currentMonth, transactionType: .expense))
        )
    }
    
    static func chartPlaceholder(index: Int) -> DashboardWidgetDefinition {
        DashboardWidgetDefinition(
            title: "Chart widget \(index)",
            type: .chart,
            primaryValue: WidgetValue(filter: WidgetFilter(timeRange: .currentYear, transactionType: .expense)),
            grouping: .month
        )
    }
}
