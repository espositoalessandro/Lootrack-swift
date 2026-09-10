import Foundation

enum DashboardWidgetWidth: Int, Hashable, Sendable {
    case single = 1
    case full = 2
}

enum DashboardWidgetPreviewContent: Hashable, Sendable {
    case numeric(value: String, detail: String?)
    case chart(value: String, points: [Double])
}

struct DashboardWidgetPreview: Identifiable, Hashable, Sendable {
    let id: UUID
    
    var title: String
    var width: DashboardWidgetWidth
    var content: DashboardWidgetPreviewContent
    
    init(id: UUID = UUID(), title: String, width: DashboardWidgetWidth, content: DashboardWidgetPreviewContent) {
        self.id = id
        self.title = title
        self.width = width
        self.content = content
    }
}

extension DashboardWidgetPreview {
    static let samples: [DashboardWidgetPreview] = [
        DashboardWidgetPreview(
            title: "Net this month",
            width: .single,
            content: .numeric(value: "€684.20", detail: "September")
        ),
        DashboardWidgetPreview(
            title: "Expenses",
            width: .single,
            content: .numeric(value: "€1,276.80", detail: "This month")
        ),
        DashboardWidgetPreview(
            title: "Monthly balance",
            width: .full,
            content: .chart(value: "€684.20", points: [320, 580, -140, 760, 410, 684])
        ),
        DashboardWidgetPreview(
            title: "Income",
            width: .single,
            content: .numeric(value: "€1,961.00", detail: "This month")
        ),
        DashboardWidgetPreview(
            title: "Going out",
            width: .single,
            content: .numeric(value: "€232.40", detail: "This month")
        ),
        DashboardWidgetPreview(
            title: "Expense trend",
            width: .full,
            content: .chart(value: "€1,276.80", points: [980, 1_320, 1_110, 1_540, 1_220, 1_276])
        )
    ]
    
    static let librarySamples = samples + [
        DashboardWidgetPreview(
            title: "Groceries",
            width: .single,
            content: .numeric(value: "€184.60", detail: "This month")
        ),
        DashboardWidgetPreview(
            title: "Average expense",
            width: .single,
            content: .numeric(value: "€37.42", detail: "This month")
        ),
        DashboardWidgetPreview(
            title: "Going out trend",
            width: .full,
            content: .chart(value: "€232.40", points: [140, 210, 175, 290, 250, 232])
        )
    ]
    
    static func numericPlaceholder(index: Int) -> DashboardWidgetPreview {
        DashboardWidgetPreview(
            title: "Numeric widget \(index)",
            width: .single,
            content: .numeric(value: "€123.45", detail: "Preview")
        )
    }
    
    static func chartPlaceholder(index: Int) -> DashboardWidgetPreview {
        DashboardWidgetPreview(
            title: "Chart widget \(index)",
            width: .full,
            content: .chart(value: "€456.78", points: [240, 510, 380, 620, 460, 720])
        )
    }
}
