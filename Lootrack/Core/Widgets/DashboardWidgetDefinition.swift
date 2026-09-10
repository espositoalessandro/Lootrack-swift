import Foundation

nonisolated enum DashboardWidgetType: String, Codable, CaseIterable, Hashable, Sendable {
    case numeric
    case chart
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
