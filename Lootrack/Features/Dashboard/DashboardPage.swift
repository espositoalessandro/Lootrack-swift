import SwiftData
import SwiftUI

struct Dashboard: View {
    @Environment(SyncCoordinator.self) private var syncCoordinator
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @Query(TransactionQueries.active) private var transactions: [Transaction]
    @Query(CategoryQueries.activeByName) private var categories: [Category]
    @Query private var records: [DashboardWidgetRecord]
    @Query(sort: \DashboardWidgetPlacement.position) private var placements: [DashboardWidgetPlacement]

    @State private var today = TransactionDate.today()
    @State private var isWidgetPickerPresented = false
    @State private var showSaveError = false
    private let evaluator = DashboardWidgetEvaluator()

    var body: some View {
        let library = records.compactMap(\.widget)
        let widgetsByID = Dictionary(uniqueKeysWithValues: library.map { ($0.id, $0) })
        let widgets = placements.compactMap { widgetsByID[$0.widgetID] }
        let activity = DashboardActivity(transactions: transactions, categories: categories, now: today)

        ScrollView {
            if widgets.isEmpty {
                ContentUnavailableView {
                    Label("No Dashboard Widgets", systemImage: "rectangle.3.group")
                } actions: {
                    Button("Add Widget") {
                        isWidgetPickerPresented = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.top, 40)
            } else {
                DashboardGridLayout(spans: widgets.map(\.width.rawValue)) {
                    ForEach(widgets) { widget in
                        card(for: widget, activity: activity)
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
                .reorderContainer(for: DashboardWidget.self) { difference in
                    apply(difference)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .syncRefreshable(using: syncCoordinator)
        .navigationTitle("Dashboard")
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
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                today = TransactionDate.today()
            }
        }
        .sheet(isPresented: $isWidgetPickerPresented) {
            let placedIDs = Set(placements.map(\.widgetID))
            AddDashboardWidgetSheet(
                widgets: library.filter { !placedIDs.contains($0.id) },
                transactions: transactions,
                onAdd: addWidget,
                onCreateNumeric: {
                    createWidget(.numericPlaceholder(index: nextCustomWidgetIndex))
                },
                onCreateChart: {
                    createWidget(.chartPlaceholder(index: nextCustomWidgetIndex))
                }
            )
        }
        .alert("Dashboard Change Failed", isPresented: $showSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The dashboard change could not be saved. Try again.")
        }
    }

    private var nextCustomWidgetIndex: Int {
        records.count { record in
            if case .custom? = record.widget { return true }
            return false
        } + 1
    }

    @ViewBuilder
    private func card(for widget: DashboardWidget, activity: DashboardActivity) -> some View {
        switch widget {
        case .builtIn(let builtIn):
            BuiltInDashboardWidgetCard(widget: builtIn, activity: activity)
        case .custom(let definition):
            DashboardWidgetCard(widget: definition, result: evaluator.evaluate(definition, transactions: transactions))
        }
    }

    private func addWidget(_ widget: DashboardWidget) {
        guard !placements.contains(where: { $0.widgetID == widget.id }) else { return }

        let nextPosition = (placements.last?.position ?? -1) + 1
        withAnimation {
            modelContext.insert(DashboardWidgetPlacement(widgetID: widget.id, position: nextPosition))
            saveChanges()
        }
    }

    private func removeWidget(_ widget: DashboardWidget) {
        guard let placement = placements.first(where: { $0.widgetID == widget.id }) else { return }

        withAnimation {
            modelContext.delete(placement)
            saveChanges()
        }
    }

    private func createWidget(_ definition: DashboardWidgetDefinition) {
        do {
            modelContext.insert(try DashboardWidgetRecord(definition))
            saveChanges()
        } catch {
            showSaveError = true
        }
    }

    private func apply(_ difference: ReorderDifference<DashboardWidget.ID, ReorderableSingleCollectionIdentifier>) {
        let sourceIDs = Set(difference.sources)
        let moved = difference.sources.compactMap { id in placements.first { $0.widgetID == id } }
        guard !moved.isEmpty else { return }

        var reordered = placements.filter { !sourceIDs.contains($0.widgetID) }
        switch difference.destination.position {
        case .before(let destinationID):
            let index = reordered.firstIndex { $0.widgetID == destinationID } ?? reordered.endIndex
            reordered.insert(contentsOf: moved, at: index)
        case .end:
            reordered.append(contentsOf: moved)
        }

        for (position, placement) in reordered.enumerated() where placement.position != position {
            placement.position = position
        }
        saveChanges()
    }

    private func saveChanges() {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            showSaveError = true
        }
    }
}
