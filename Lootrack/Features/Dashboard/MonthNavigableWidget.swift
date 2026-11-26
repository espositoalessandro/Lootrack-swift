import SwiftUI
import UIKit

struct MonthNavigableWidget<Header: View, Content: View>: View {
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedMonth: Date?
    @State private var isPickerPresented = false
    @State private var pageWidth: CGFloat = 0
    @State private var pagePosition: CGFloat = 0
    @State private var isSettling = false

    let calendar: Calendar
    let availableMonths: ClosedRange<Date>
    let defaultMonth: Date
    @ViewBuilder let header: () -> Header
    @ViewBuilder let content: (Date) -> Content

    init(calendar: Calendar,
         availableMonths: ClosedRange<Date>,
         defaultMonth: Date,
         @ViewBuilder header: @escaping () -> Header,
         @ViewBuilder content: @escaping (Date) -> Content) {
        self.calendar = calendar
        let firstMonth = calendar.dateInterval(of: .month, for: availableMonths.lowerBound)?.start ?? availableMonths.lowerBound
        let lastMonth = calendar.dateInterval(of: .month, for: availableMonths.upperBound)?.start ?? availableMonths.upperBound
        self.availableMonths = firstMonth ... lastMonth
        self.defaultMonth = calendar.dateInterval(of: .month, for: defaultMonth)?.start ?? defaultMonth
        self.header = header
        self.content = content
    }

    private var month: Date {
        min(max(selectedMonth ?? defaultMonth, availableMonths.lowerBound), availableMonths.upperBound)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                header()
                    .frame(maxWidth: .infinity, alignment: .leading)
                monthButton
            }
            monthPages
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect(cornerRadius: 20))
        .gesture(HorizontalSwipe(onChanged: dragPage,
                                 onCancelled: { settlePage(at: 0) },
                                 onEnded: finishDrag))
    }

    private var monthPages: some View {
        let current = month
        let pages = [adjacentMonth(-1), current, adjacentMonth(1)].compactMap { $0 }

        return MonthPageLayout(position: pagePosition) {
            ForEach(pages, id: \.self) { page in
                content(page)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .allowsHitTesting(page == current && !isSettling)
                    .accessibilityHidden(page != current)
                    .layoutValue(key: MonthPageIndex.self, value: page == current ? 0 : (page < current ? -1 : 1))
            }
        }
        .clipped()
        .onGeometryChange(for: CGFloat.self) { geometry in
            geometry.size.width
        } action: { width in
            pageWidth = width
        }
    }

    private var monthButton: some View {
        let format = dateFormat(.dateTime.month(.abbreviated).year(), calendar: calendar, locale: locale)
        let fullFormat = dateFormat(.dateTime.month(.wide).year(), calendar: calendar, locale: locale)

        return Button {
            isPickerPresented = true
        } label: {
            Text(month, format: format)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.quaternary, in: Capsule())
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isSettling)
        .accessibilityLabel(Text(month, format: fullFormat))
        .accessibilityHint(Text("Choose a month"))
        .accessibilityAction(named: Text("Previous Month")) { moveMonth(-1) }
        .accessibilityAction(named: Text("Next Month")) { moveMonth(1) }
        .popover(isPresented: $isPickerPresented) {
            MonthCalendarPicker(calendar: calendar, availableMonths: availableMonths, selection: month) { pickedMonth in
                selectedMonth = pickedMonth
                isPickerPresented = false
            }
            .presentationCompactAdaptation(.popover)
        }
    }

    private func adjacentMonth(_ offset: Int) -> Date? {
        guard let destination = calendar.date(byAdding: .month, value: offset, to: month),
              availableMonths.contains(destination)
        else { return nil }

        return destination
    }

    private func moveMonth(_ offset: Int) {
        guard let destination = adjacentMonth(offset) else { return }

        settlePage(at: -CGFloat(offset), selecting: destination)
    }

    private func dragPage(_ translation: CGFloat) {
        guard !reduceMotion, !isSettling, pageWidth > 0 else { return }

        let offset = translation < 0 ? 1 : -1
        pagePosition = adjacentMonth(offset) == nil ? 0 : min(max(translation / pageWidth, -1), 1)
    }

    private func finishDrag(_ translation: CGFloat, velocity: CGFloat) {
        let threshold = pageWidth > 0 ? min(44, pageWidth * 0.2) : 44
        let flicked = abs(translation) >= 16 && abs(velocity) >= 450 && translation * velocity > 0
        let offset = translation < 0 ? 1 : -1

        if abs(translation) >= threshold || flicked, let destination = adjacentMonth(offset) {
            settlePage(at: -CGFloat(offset), selecting: destination)
        } else {
            settlePage(at: 0)
        }
    }

    private func settlePage(at position: CGFloat, selecting destination: Date? = nil) {
        guard !isSettling else { return }

        if reduceMotion || pagePosition == position {
            resetPage(selecting: destination)
            return
        }

        // Keep both pages in place until the incoming page reaches the center.
        isSettling = true
        withAnimation(.easeOut(duration: 0.23), completionCriteria: .removed) {
            pagePosition = position
        } completion: {
            resetPage(selecting: destination)
        }
    }

    private func resetPage(selecting destination: Date?) {
        var transaction = SwiftUI.Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if let destination { selectedMonth = destination }
            pagePosition = 0
            isSettling = false
        }
    }
}

private nonisolated enum MonthPageIndex: LayoutValueKey {
    static let defaultValue = 0
}

private nonisolated struct MonthPageLayout: Layout {
    var position: CGFloat

    var animatableData: CGFloat {
        get { position }
        set { position = newValue }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let current = subviews.first(where: { $0[MonthPageIndex.self] == 0 }) else { return .zero }

        let width = proposal.width ?? current.sizeThatFits(.unspecified).width
        let pageProposal = ProposedViewSize(width: width, height: nil)
        let height = current.sizeThatFits(pageProposal).height
        let neighborIndex = position < 0 ? 1 : -1
        guard position != 0, let neighbor = subviews.first(where: { $0[MonthPageIndex.self] == neighborIndex }) else {
            return CGSize(width: width, height: height)
        }

        let neighborHeight = neighbor.sizeThatFits(pageProposal).height
        return CGSize(width: width, height: height + (neighborHeight - height) * abs(position))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let pageProposal = ProposedViewSize(width: bounds.width, height: nil)
        for page in subviews {
            let x = bounds.midX + (CGFloat(page[MonthPageIndex.self]) + position) * bounds.width
            page.place(at: CGPoint(x: x, y: bounds.minY), anchor: .top, proposal: pageProposal)
        }
    }
}

private struct MonthCalendarPicker: View {
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var displayedYear: Date?

    let calendar: Calendar
    let availableMonths: ClosedRange<Date>
    let selection: Date
    let onSelect: (Date) -> Void

    private var firstYear: Date { startOfYear(for: availableMonths.lowerBound) }
    private var lastYear: Date { startOfYear(for: availableMonths.upperBound) }
    private var year: Date { min(max(displayedYear ?? startOfYear(for: selection), firstYear), lastYear) }

    private var years: [Date] {
        let span = calendar.dateComponents([.year], from: firstYear, to: lastYear).year ?? 0
        return (0 ... span).reversed().compactMap { calendar.date(byAdding: .year, value: $0, to: firstYear) }
    }

    private var months: [Date] {
        let count = calendar.range(of: .month, in: .year, for: year)?.count ?? 0
        return (0 ..< count).compactMap { calendar.date(byAdding: .month, value: $0, to: year) }
    }

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: textSize.isAccessibilitySize ? 2 : 3)
        let monthFormat = dateFormat(.dateTime.month(.abbreviated), calendar: calendar, locale: locale)
        let fullMonthFormat = dateFormat(.dateTime.month(.wide).year(), calendar: calendar, locale: locale)

        VStack(spacing: 10) {
            yearPicker
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(months, id: \.self) { month in
                    Button {
                        onSelect(month)
                    } label: {
                        Text(month, format: monthFormat)
                            .font(.subheadline.weight(month == selection ? .semibold : .regular))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(month == selection ? Color.accentColor.opacity(0.15) : .clear,
                                        in: .rect(cornerRadius: 8))
                            .contentShape(.rect(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(!availableMonths.contains(month))
                    .accessibilityLabel(Text(month, format: fullMonthFormat))
                    .accessibilityAddTraits(month == selection ? .isSelected : [])
                }
            }
        }
        .frame(width: 250)
        .padding(16)
        .contentShape(Rectangle())
        .gesture(HorizontalSwipe { translation, _ in
            if abs(translation) >= 40 { moveYear(translation < 0 ? 1 : -1) }
        })
    }

    @ViewBuilder
    private var yearPicker: some View {
        let format = dateFormat(.dateTime.year(), calendar: calendar, locale: locale)

        if firstYear == lastYear {
            Text(year, format: format)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
        } else {
            Picker("Year", selection: Binding(get: { year }, set: { displayedYear = $0 })) {
                ForEach(years, id: \.self) { year in
                    Text(year, format: format).tag(year)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private func startOfYear(for date: Date) -> Date {
        calendar.dateInterval(of: .year, for: date)?.start ?? date
    }

    private func moveYear(_ offset: Int) {
        guard let destination = calendar.date(byAdding: .year, value: offset, to: year),
              (firstYear ... lastYear).contains(destination)
        else { return }

        displayedYear = destination
    }
}

private struct HorizontalSwipe: UIGestureRecognizerRepresentable {
    var onChanged: (CGFloat) -> Void = { _ in }
    var onCancelled: () -> Void = {}
    let onEnded: (CGFloat, CGFloat) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.maximumNumberOfTouches = 1
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let translation = recognizer.translation(in: recognizer.view)
        switch recognizer.state {
        case .changed:
            onChanged(translation.x)
        case .ended where abs(translation.x) > abs(translation.y):
            onEnded(translation.x, recognizer.velocity(in: recognizer.view).x)
        case .ended, .cancelled, .failed:
            onCancelled()
        default:
            break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }

            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            let scrollView = otherGestureRecognizer.view as? UIScrollView
            return otherGestureRecognizer === scrollView?.panGestureRecognizer
        }
    }
}

private func dateFormat(_ style: Date.FormatStyle, calendar: Calendar, locale: Locale) -> Date.FormatStyle {
    var format = style.locale(locale)
    format.calendar = calendar
    format.timeZone = calendar.timeZone
    return format
}
