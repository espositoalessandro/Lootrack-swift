import SwiftUI

struct AddDashboardWidgetSheet: View {
    @Environment(\.dismiss) private var dismiss

    let widgets: [DashboardWidget]
    let transactions: [Transaction]
    let onAdd: (DashboardWidget) -> Void
    let onCreateNumeric: () -> Void
    let onCreateChart: () -> Void

    private let evaluator = DashboardWidgetEvaluator()

    private var builtIns: [BuiltInDashboardWidget] {
        let availableIDs = Set(widgets.map(\.id))
        return BuiltInDashboardWidget.allCases.filter { availableIDs.contains($0.id) }
    }

    private var customWidgets: [DashboardWidgetDefinition] {
        widgets.compactMap { widget in
            if case .custom(let definition) = widget { return definition }
            return nil
        }
        .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if widgets.isEmpty {
                    ContentUnavailableView(
                        "No Widgets Available",
                        systemImage: "rectangle.3.group",
                        description: Text("Create a new widget or remove one from the Dashboard.")
                    )
                    .padding(.top, 80)
                } else {
                    VStack(spacing: 12) {
                        ForEach(builtIns) { widget in
                            builtInRow(widget)
                        }
                        DashboardGridLayout(spans: customWidgets.map(\.width.rawValue)) {
                            ForEach(customWidgets) { widget in
                                Button {
                                    add(.custom(widget))
                                } label: {
                                    DashboardWidgetCard(widget: widget, result: evaluator.evaluate(widget, transactions: transactions))
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Add Widget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    createWidgetMenu
                }
            }
        }
    }

    private func builtInRow(_ widget: BuiltInDashboardWidget) -> some View {
        Button {
            add(.builtIn(widget))
        } label: {
            HStack(spacing: 12) {
                Label {
                    Text(widget.title)
                } icon: {
                    Image(systemName: widget.symbol)
                        .foregroundStyle(.tint)
                }
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .background(.thinMaterial, in: .rect(cornerRadius: 16))
            .contentShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private func add(_ widget: DashboardWidget) {
        onAdd(widget)
        dismiss()
    }

    private var createWidgetMenu: some View {
        Menu {
            Button {
                onCreateNumeric()
            } label: {
                Label("Numeric", systemImage: "number")
            }

            Button {
                onCreateChart()
            } label: {
                Label("Chart", systemImage: "chart.xyaxis.line")
            }
        } label: {
            Image(systemName: "plus")
        }
        .accessibilityLabel("Create Widget")
    }
}
