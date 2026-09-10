import SwiftData
import SwiftUI

struct Dashboard: View {
    @Environment(SyncCoordinator.self)
    private var syncCoordinator
    
    @Query(TransactionQueries.active)
    private var transactions: [Transaction]
    
    @State
    private var allWidgets = DashboardWidgetDefinition.librarySamples
    
    @State
    private var widgets = DashboardWidgetDefinition.samples
    
    @State
    private var isWidgetPickerPresented = false
    
    private let evaluator = DashboardWidgetEvaluator()
    
    private var unusedWidgets: [DashboardWidgetDefinition] {
        let dashboardWidgetIDs = Set(widgets.map(\.id))
        return allWidgets.filter { !dashboardWidgetIDs.contains($0.id) }
    }
    
    var body: some View {
        ScrollView {
            DashboardGridLayout(spans: widgets.map(\.width.rawValue), horizontalSpacing: 12, verticalSpacing: 12) {
                ForEach(widgets) { widget in
                    DashboardWidgetCard(widget: widget, result: evaluator.evaluate(widget, transactions: transactions))
                        .contextMenu {
                            Button {
                                removeWidget(widget)
                            } label: {
                                Label("Remove from Dashboard", systemImage: "minus.circle")
                            }
                        }
                }
                .reorderable()
            }
            .reorderContainer(for: DashboardWidgetDefinition.self) { difference in
                apply(difference)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .refreshable {
            await syncCoordinator.synchronize()
        }
        .navigationTitle("Lootrack")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isWidgetPickerPresented = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add Widget")
            }
        }
        .sheet(isPresented: $isWidgetPickerPresented) {
            AddDashboardWidgetSheet(
                widgets: unusedWidgets,
                transactions: transactions,
                onAdd: addWidget,
                onCreateNumeric: createNumericWidget,
                onCreateChart: createChartWidget
            )
        }
    }
    
    private func addWidget(_ widget: DashboardWidgetDefinition) {
        guard !widgets.contains(where: { $0.id == widget.id }) else {
            return
        }
        
        withAnimation {
            widgets.append(widget)
        }
    }
    
    private func removeWidget(_ widget: DashboardWidgetDefinition) {
        withAnimation {
            widgets.removeAll { $0.id == widget.id }
        }
    }
    
    private func createNumericWidget() {
        let widget = DashboardWidgetDefinition.numericPlaceholder(index: allWidgets.count + 1)
        
        withAnimation {
            allWidgets.append(widget)
        }
    }
    
    private func createChartWidget() {
        let widget = DashboardWidgetDefinition.chartPlaceholder(index: allWidgets.count + 1)
        
        withAnimation {
            allWidgets.append(widget)
        }
    }
    
    private func apply(
        _ difference: ReorderDifference<DashboardWidgetDefinition.ID, ReorderableSingleCollectionIdentifier>
    ) {
        let sourceIDs = difference.sources
        let movedWidgets = sourceIDs.compactMap { sourceID in
            widgets.first { $0.id == sourceID }
        }
        
        widgets.removeAll { sourceIDs.contains($0.id) }
        
        switch difference.destination.position {
        case .before(let destinationID):
            guard let destinationIndex = widgets.firstIndex(where: { $0.id == destinationID }) else {
                widgets.append(contentsOf: movedWidgets)
                return
            }
            
            widgets.insert(contentsOf: movedWidgets, at: destinationIndex)
            
        case .end:
            widgets.append(contentsOf: movedWidgets)
        }
    }
}
