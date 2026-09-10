import Charts
import SwiftUI

struct DashboardWidgetCard: View {
    @Environment(AppSettings.self)
    private var settings
    
    let widget: DashboardWidgetDefinition
    let result: DashboardWidgetResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(widget.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            
            widgetContent
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: minimumHeight, alignment: .leading)
        .background(.thinMaterial, in: .rect(cornerRadius: 20))
    }
    
    @ViewBuilder
    private var widgetContent: some View {
        switch result {
        case .numeric(let valueInCents):
            Spacer(minLength: 8)
            
            Text(settings.formattedAmount(valueInCents))
                .font(.title2)
                .fontWeight(.bold)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
        case .chart(let points):
            Text(settings.formattedAmount(points.last?.valueInCents ?? 0))
                .font(.title2)
                .fontWeight(.bold)
                .monospacedDigit()
            
            Chart(points) { point in
                LineMark(
                    x: .value("Period", point.date),
                    y: .value("Value", point.valueInCents)
                )
                .foregroundStyle(Color.accentColor)
                .interpolationMethod(.catmullRom)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 110)
        }
    }
    
    private var minimumHeight: CGFloat {
        switch widget.type {
        case .numeric:
            125
        case .chart:
            210
        }
    }
}
