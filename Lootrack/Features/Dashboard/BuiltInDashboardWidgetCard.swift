import Charts
import SwiftUI

struct BuiltInDashboardWidgetCard: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.locale) private var locale
    @State private var selectedMonth: Date?
    @State private var categoryType: TransactionType = .expense
    @State private var showAllCategories = false

    let widget: BuiltInDashboardWidget
    let activity: DashboardActivity

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label {
                Text(widget.title)
            } icon: {
                Image(systemName: widget.symbol)
                    .foregroundStyle(.tint)
            }
            .font(.headline)
            .accessibilityAddTraits(.isHeader)

            switch widget {
            case .monthlyNet: monthlyNet
            case .spendingByCategory: spendingByCategory
            case .monthlyBalanceTrend: balanceTrend
            case .monthlyAverages: monthlyAverages
            case .categoryAverages: categoryAverages
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: .rect(cornerRadius: 20))
    }

    private var month: Date {
        min(max(selectedMonth ?? activity.currentMonth, activity.firstMonth), activity.lastMonth)
    }

    private var monthFormat: Date.FormatStyle {
        var style = Date.FormatStyle.dateTime.month(.wide).year().locale(locale)
        style.timeZone = TransactionDate.timeZone
        style.calendar = TransactionDate.calendar
        return style
    }

    private var monthPicker: some View {
        HStack(spacing: 2) {
            monthButton(-1, label: "Previous Month", icon: "chevron.backward")
            Text(month, format: monthFormat)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.updatesFrequently)
            monthButton(1, label: "Next Month", icon: "chevron.forward")
        }
        .background(.quaternary, in: .rect(cornerRadius: 12))
    }

    private func monthButton(_ offset: Int, label: LocalizedStringKey, icon: String) -> some View {
        let destination = activity.month(byAdding: offset, to: month)

        return Button {
            selectedMonth = destination
        } label: {
            Image(systemName: icon)
                .font(.footnote.weight(.semibold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(destination == nil ? Color.secondary : Color.accentColor)
        .disabled(destination == nil)
        .accessibilityLabel(Text(label))
    }

    private var monthlyNet: some View {
        let totals = activity.totals(for: month)

        return VStack(alignment: .leading, spacing: 12) {
            monthPicker
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

    private var spendingByCategory: some View {
        let rows = activity.spendingByCategory(in: month)

        return VStack(alignment: .leading, spacing: 12) {
            monthPicker
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

    private var categoryAverages: some View {
        let rows = activity.averageByCategory(for: categoryType)

        return VStack(alignment: .leading, spacing: 12) {
            Picker("Transaction Type", selection: $categoryType) {
                Text("Expenses").tag(TransactionType.expense)
                Text("Income").tag(TransactionType.income)
            }
            .pickerStyle(.segmented)

            if rows.isEmpty {
                emptyMessage("No transactions for this type.")
            } else {
                monthCountLabel
                categoryRows(rows)
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

    private func categoryRows(_ rows: [DashboardActivity.CategoryAmount], total: Int? = nil) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(rows.prefix(4)) { row in
                categoryRow(row, total: total)
            }
            if rows.count > 4 {
                DisclosureGroup("More Categories", isExpanded: $showAllCategories) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(rows.dropFirst(4)) { row in
                            categoryRow(row, total: total)
                        }
                    }
                    .padding(.top, 8)
                }
                .font(.subheadline)
            }
        }
    }

    private func categoryRow(_ row: DashboardActivity.CategoryAmount, total: Int?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            LabeledContent {
                Text(settings.formattedAmount(row.cents))
                    .monospacedDigit()
            } label: {
                if let name = row.name {
                    Text(name)
                } else {
                    Text("Uncategorized")
                }
            }
            .font(.subheadline)

            if let total, total > 0 {
                ProgressView(value: min(max(Double(row.cents) / Double(total), 0), 1))
                    .accessibilityHidden(true)
            }
        }
    }
}
