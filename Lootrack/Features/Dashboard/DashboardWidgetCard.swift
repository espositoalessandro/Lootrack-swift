import Charts
import SwiftUI

struct DashboardWidgetCard: View {
    let widget: DashboardWidgetPreview

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            Text(widget.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            widgetContent
        }
        .padding(16)
        .frame(
            maxWidth: .infinity,
            minHeight: minimumHeight,
            alignment: .leading
        )
        .background(
            .thinMaterial,
            in: .rect(
                cornerRadius: 20
            )
        )
    }

    @ViewBuilder
    private var widgetContent: some View {
        switch widget.content {
        case let .numeric(
            value,
            detail
        ):
            Spacer(
                minLength: 8
            )

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case let .chart(
            value,
            points
        ):
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .monospacedDigit()

            Chart(
                0 ..< points.count,
                id: \.self
            ) {
                index in

                LineMark(
                    x: .value(
                        "Period",
                        index
                    ),
                    y: .value(
                        "Value",
                        points[index]
                    )
                )
                .foregroundStyle(
                    Color.accentColor
                )
                .interpolationMethod(
                    .catmullRom
                )
            }
            .chartXAxis(
                .hidden
            )
            .chartYAxis(
                .hidden
            )
            .frame(
                height: 110
            )
        }
    }

    private var minimumHeight: CGFloat {
        switch widget.content {
        case .numeric:
            125

        case .chart:
            210
        }
    }
}