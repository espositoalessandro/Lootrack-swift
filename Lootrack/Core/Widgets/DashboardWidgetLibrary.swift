import Foundation
import SwiftData

enum BuiltInDashboardWidget: String, CaseIterable, Identifiable {
    case monthlyNet
    case spendingByCategory
    case monthlyBalanceTrend
    case monthlyAverages
    case categoryAverages

    var id: String { "built-in.\(rawValue)" }

    var title: LocalizedStringResource {
        switch self {
        case .monthlyNet: "Monthly Net"
        case .spendingByCategory: "Spending by Category"
        case .monthlyBalanceTrend: "Monthly Balance Trend"
        case .monthlyAverages: "Monthly Averages"
        case .categoryAverages: "Category Averages"
        }
    }

    var symbol: String {
        switch self {
        case .monthlyNet: "arrow.up.arrow.down"
        case .spendingByCategory: "chart.bar.xaxis"
        case .monthlyBalanceTrend: "chart.bar"
        case .monthlyAverages: "sum"
        case .categoryAverages: "square.grid.2x2"
        }
    }
}

enum DashboardWidget: Identifiable {
    case builtIn(BuiltInDashboardWidget)
    case custom(DashboardWidgetDefinition)

    var id: String {
        switch self {
        case .builtIn(let widget): widget.id
        case .custom(let widget): widget.id.uuidString
        }
    }

    var width: DashboardWidgetWidth {
        switch self {
        case .builtIn: .full
        case .custom(let widget): widget.width
        }
    }
}

@Model
final class DashboardWidgetRecord {
    @Attribute(.unique) var id: String
    private var customDefinition: Data?

    init(_ builtIn: BuiltInDashboardWidget) {
        id = builtIn.id
    }

    init(_ definition: DashboardWidgetDefinition) throws {
        id = definition.id.uuidString
        customDefinition = try JSONEncoder().encode(definition)
    }

    var widget: DashboardWidget? {
        if let builtIn = BuiltInDashboardWidget.allCases.first(where: { $0.id == id }) {
            return .builtIn(builtIn)
        }

        guard let customDefinition,
              let definition = try? JSONDecoder().decode(DashboardWidgetDefinition.self, from: customDefinition)
        else { return nil }

        return .custom(definition)
    }

    static func installBuiltIns(in context: ModelContext) throws {
        let existingIDs = Set(try context.fetch(FetchDescriptor<DashboardWidgetRecord>()).map(\.id))
        for (position, widget) in BuiltInDashboardWidget.allCases.enumerated() where !existingIDs.contains(widget.id) {
            context.insert(DashboardWidgetRecord(widget))

            // Seed the initial dashboard once. A later launch must respect removed placements.
            if existingIDs.isEmpty {
                context.insert(DashboardWidgetPlacement(widgetID: widget.id, position: position))
            }
        }

        if context.hasChanges {
            try context.save()
        }
    }
}

@Model
final class DashboardWidgetPlacement {
    @Attribute(.unique) var widgetID: String
    var position: Int

    init(widgetID: String, position: Int) {
        self.widgetID = widgetID
        self.position = position
    }
}
