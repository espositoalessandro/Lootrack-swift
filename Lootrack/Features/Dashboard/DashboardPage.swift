import SwiftUI

struct Dashboard: View {
    @Environment(SyncCoordinator.self)
    private var syncCoordinator

    @State
    private var widgets = DashboardWidgetPreview.samples

    var body: some View {
        ScrollView {
            DashboardGridLayout(
                spans: widgets.map(\.width.rawValue),
                horizontalSpacing: 12,
                verticalSpacing: 12
            ) {
                ForEach(widgets) { widget in
                    DashboardWidgetCard(widget: widget)
                }
                .reorderable()
            }
            .reorderContainer(for: DashboardWidgetPreview.self) {
                difference in apply(difference)
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
                addWidgetMenu
            }
        }
    }

    private var addWidgetMenu: some View {
        Menu {
            Button {
                addNumericWidget()
            } label: {
                Label(
                    "Numeric",
                    systemImage: "number"
                )
            }

            Button {
                addChartWidget()
            } label: {
                Label(
                    "Chart",
                    systemImage: "chart.xyaxis.line"
                )
            }
        } label: {
            Image(
                systemName: "plus"
            )
        }
        .accessibilityLabel(
            "Add Widget"
        )
    }

    private func addNumericWidget() {
        withAnimation {
            widgets.append(
                .numericPlaceholder(
                    index: widgets.count + 1
                )
            )
        }
    }

    private func addChartWidget() {
        withAnimation {
            widgets.append(
                .chartPlaceholder(
                    index: widgets.count + 1
                )
            )
        }
    }

    private func apply(
        _ difference: ReorderDifference<
            DashboardWidgetPreview.ID,
            ReorderableSingleCollectionIdentifier
        >
    ) {
        let sourceIDs =
            difference.sources

        let movedWidgets =
            sourceIDs.compactMap {
                sourceID in

                widgets.first {
                    $0.id == sourceID
                }
            }

        widgets.removeAll {
            sourceIDs.contains(
                $0.id
            )
        }

        switch difference.destination.position {
        case .before(
            let
                destinationID
        ):
            guard
                let destinationIndex =
                    widgets.firstIndex(
                        where: {
                            $0.id == destinationID
                        }
                    )
            else {
                widgets.append(
                    contentsOf: movedWidgets
                )
                return
            }

            widgets.insert(
                contentsOf: movedWidgets,
                at: destinationIndex
            )

        case .end:
            widgets.append(
                contentsOf: movedWidgets
            )
        }
    }
}
