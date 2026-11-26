import Charts
import SwiftUI

struct BuiltInDashboardWidgetCard: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.locale) private var locale
    @State private var showAllCategories = false

    let widget: BuiltInDashboardWidget
    let activity: DashboardActivity

    var body: some View {
        Group {
            switch widget {
            case .monthlyNet:
                monthCard { month in monthlyNet(for: month) }
            case .spendingByCategory:
                monthCard { month in spendingByCategory(for: month) }
            case .monthlyBalanceTrend:
                staticCard { balanceTrend }
            case .monthlyAverages:
                staticCard { monthlyAverages }
            }
        }
        .background(.thinMaterial, in: .rect(cornerRadius: 20))
    }

    private var heading: some View {
        Label {
            Text(widget.title)
        } icon: {
            Image(systemName: widget.symbol)
                .foregroundStyle(.tint)
        }
        .font(.headline)
        .accessibilityAddTraits(.isHeader)
    }

    private func monthCard<Content: View>(@ViewBuilder content: @escaping (Date) -> Content) -> some View {
        MonthNavigableWidget(
            calendar: TransactionDate.calendar,
            availableMonths: activity.firstMonth ... activity.lastMonth,
            defaultMonth: activity.currentMonth,
            header: { heading },
            content: content
        )
    }

    private func staticCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            heading
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var monthFormat: Date.FormatStyle {
        var style = Date.FormatStyle.dateTime.month(.wide).year().locale(locale)
        style.timeZone = TransactionDate.timeZone
        style.calendar = TransactionDate.calendar
        return style
    }

    private func monthlyNet(for month: Date) -> some View {
        let totals = activity.totals(for: month)

        return VStack(alignment: .leading, spacing: 12) {
            if activity.hasTransactions(in: month) {
                headlineAmount(totals.net)
                    .accessibilityLabel(Text("Net"))
                    .accessibilityValue(Text(settings.formattedAmount(totals.net)))
                Divider()
                metric("Income", cents: totals.income)
                metric("Expenses", cents: totals.expenses)
            } else {
                emptyMessage("No transactions this month.")
            }
        }
    }

    private func spendingByCategory(for month: Date) -> some View {
        let rows = activity.spendingByCategory(in: month)

        return VStack(alignment: .leading, spacing: 12) {
            if rows.isEmpty {
                emptyMessage("No expenses this month.")
            } else {
                let total = activity.totals(for: month).expenses
                metric("Total Expenses", cents: total)
                    .fontWeight(.semibold)
                Divider()
                categoryRows(rows, total: total)
            }
        }
    }

    private var balanceTrend: some View {
        VStack(alignment: .leading, spacing: 10) {
            if activity.loggedMonthCount == 0 {
                emptyMessage("Add transactions to see your balance trend.")
            } else {
                Text("Balance across months")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                headlineAmount(activity.totals.net)
                monthlyNetChart(activity.trendMonths)
            }
        }
    }

    private func monthlyNetChart(_ months: [Date]) -> some View {
        let calendar = TransactionDate.calendar
        let visibleMonthCount = 6
        let visibleStart = months.suffix(visibleMonthCount).first ?? activity.firstMonth
        let domainEnd = calendar.dateInterval(of: .month, for: activity.lastMonth)?.end ?? activity.lastMonth
        var axisDate = Date.FormatStyle.dateTime.month(.abbreviated).year(.twoDigits).locale(locale)
        axisDate.timeZone = calendar.timeZone
        axisDate.calendar = calendar

        return Chart(months, id: \.self) { month in
            let net = activity.totals(for: month).net
            BarMark(
                x: .value("Month", month, unit: .month, calendar: calendar),
                y: .value("Net", Double(net) / 100)
            )
            .foregroundStyle(net < 0 ? Color.red : Color.accentColor)
            .cornerRadius(3)
            .accessibilityLabel(Text(month, format: monthFormat))
            .accessibilityValue(Text(settings.formattedAmount(net)))
        }
        .chartXScale(domain: activity.firstMonth ... domainEnd, range: .plotDimension(padding: 0))
        .chartScrollableAxes(months.count > visibleMonthCount ? .horizontal : [])
        .chartXVisibleDomain(length: domainEnd.timeIntervalSince(visibleStart))
        .chartScrollPosition(initialX: visibleStart)
        .chartXAxis {
            AxisMarks(values: months) {
                AxisValueLabel(format: axisDate, centered: true)
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) {
                AxisGridLine()
                AxisValueLabel(format: FloatingPointFormatStyle<Double>.Currency(code: settings.resolvedCurrencyCode)
                    .precision(.fractionLength(0))
                    .locale(locale))
            }
        }
        .environment(\.calendar, calendar)
        .environment(\.timeZone, calendar.timeZone)
        .frame(height: 146)
        .accessibilityLabel(Text("Monthly Net"))
    }

    private var monthlyAverages: some View {
        Group {
            if activity.loggedMonthCount == 0 {
                emptyMessage("Add transactions to see monthly averages.")
            } else {
                monthCountLabel
                metric("Income", cents: activity.averageIncome)
                metric("Expenses", cents: activity.averageExpenses)
                Divider()
                metric("Net", cents: activity.averageNet)
                    .fontWeight(.semibold)
            }
        }
    }

    private var monthCountLabel: some View {
        Text("Based on \(activity.loggedMonthCount) logged months")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private func headlineAmount(_ cents: Int) -> some View {
        Text(settings.formattedAmount(cents))
            .font(.largeTitle.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(cents < 0 ? Color.red : Color.primary)
            .minimumScaleFactor(0.65)
            .lineLimit(1)
    }

    private func metric(_ title: LocalizedStringKey, cents: Int) -> some View {
        LabeledContent(title) {
            Text(settings.formattedAmount(cents))
                .monospacedDigit()
        }
    }

    private func emptyMessage(_ message: LocalizedStringKey) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func categoryRows(_ rows: [DashboardActivity.CategorySpending], total: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                ForEach(showAllCategories ? rows[...] : rows.prefix(4)) { row in
                    categoryRow(row)
                    if total > 0, row.currentCents > 0 {
                        ProgressView(value: min(Double(row.currentCents) / Double(total), 1))
                            .padding(.bottom, 4)
                            .accessibilityHidden(true)
                    }
                }
            }
            if rows.count > 4 {
                Button {
                    withAnimation { showAllCategories.toggle() }
                } label: {
                    HStack {
                        if showAllCategories {
                            Text("Fewer Categories")
                        } else {
                            Text("More Categories")
                        }
                        Spacer()
                        Image(systemName: showAllCategories ? "chevron.up" : "chevron.down")
                            .accessibilityHidden(true)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .font(.subheadline)
                .foregroundStyle(.tint)
            }
        }
    }

    private func categoryRow(_ row: DashboardActivity.CategorySpending) -> some View {
        let average = settings.formattedAmount(row.averageCents)

        return GridRow {
            Group {
                if let name = row.name {
                    Text(name)
                } else {
                    Text("Uncategorized")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(settings.formattedAmount(row.currentCents))
                .multilineTextAlignment(.trailing)
                .gridColumnAlignment(.trailing)

            Text("\(average) avg")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .gridColumnAlignment(.trailing)
                .accessibilityLabel(Text("Monthly average \(average)"))
        }
        .font(.subheadline)
        .monospacedDigit()
    }
}
