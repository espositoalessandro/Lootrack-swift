import SwiftUI

struct AddDashboardWidgetSheet: View {
    @Environment(\.dismiss)
    private var dismiss
    
    let widgets: [DashboardWidgetDefinition]
    let transactions: [Transaction]
    let onAdd: (DashboardWidgetDefinition) -> Void
    let onCreateNumeric: () -> Void
    let onCreateChart: () -> Void
    
    private let evaluator = DashboardWidgetEvaluator()
    
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
                    DashboardGridLayout(spans: widgets.map(\.width.rawValue), horizontalSpacing: 12, verticalSpacing: 12) {
                        ForEach(widgets) { widget in
                            DashboardWidgetCard(widget: widget, result: evaluator.evaluate(widget, transactions: transactions))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onAdd(widget)
                                    dismiss()
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
