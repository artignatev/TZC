import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingZonePicker = false
    @State private var showingCalendar = false
    @State private var draggingItem: ZoneItem?
    @State private var dragStartIndex: Int?
    @State private var dragTargetIndex: Int?
    @State private var rowDragOffset: CGFloat = 0

    private let panelWidth: CGFloat = 300
    private let timelineHeight: CGFloat = 80
    private let rowHeight: CGFloat = 90
    private let footerHeight: CGFloat = 51
    private let calendarHeight: CGFloat = 190
    private let maximumVisibleRows = 5

    var body: some View {
        ZStack {
            if showingZonePicker {
                ZonePickerView(isPresented: $showingZonePicker)
                    .transition(.opacity)
            } else {
                mainPanel
                    .transition(.opacity)
            }
        }
        .frame(width: panelWidth, height: panelHeight)
        .background(model.theme.palette.background)
        .preferredColorScheme(model.theme.colorScheme)
        .clipped()
        .animation(.easeInOut(duration: 0.25), value: showingZonePicker)
        .animation(.interactiveSpring(response: 0.34, dampingFraction: 0.84), value: showingCalendar)
        .animation(.easeInOut(duration: 0.18), value: model.zones.count)
    }

    private var mainPanel: some View {
        TimelineView(.periodic(from: .now, by: 10)) { context in
            let selectedDate = model.selectedDate(now: context.date)

            VStack(spacing: 0) {
                if showingCalendar {
                    MiniCalendarView(selectedDate: selectedDate)
                        .frame(height: calendarHeight)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                TimelineScrubber {
                    withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.84)) {
                        showingCalendar.toggle()
                    }
                }
                .environmentObject(model)

                zoneList(date: selectedDate)

                footer
            }
        }
    }

    private func zoneList(date: Date) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if model.zones.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showingZonePicker = true
                        }
                    } label: {
                        Text("Use Plus Button to Add a City")
                            .font(.system(size: 14, weight: .ultraLight))
                            .foregroundStyle(model.theme.palette.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: rowHeight)
                    }
                    .buttonStyle(.plain)
                } else {
                    ForEach(model.zones) { item in
                        CloneZoneRow(
                            item: item,
                            showsDivider: item.id != model.zones.last?.id,
                            date: date,
                            rowHeight: rowHeight,
                            remove: {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    model.remove(item)
                                }
                            }
                        )
                        .offset(y: reorderOffset(for: item))
                        .animation(
                            draggingItem?.id == item.id ? nil : .easeInOut(duration: 0.14),
                            value: dragTargetIndex
                        )
                        .zIndex(draggingItem?.id == item.id ? 2 : 0)
                        .shadow(
                            color: draggingItem?.id == item.id ? .black.opacity(0.14) : .clear,
                            radius: 7,
                            y: 2
                        )
                        .gesture(rowReorderGesture(for: item))
                    }
                }
            }
        }
        .scrollIndicators(model.zones.count > maximumVisibleRows ? .visible : .hidden)
        .frame(height: listHeight)
        .background(model.theme.palette.background)
    }

    private var footer: some View {
        let palette = model.theme.palette

        return HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showingZonePicker = true
                    showingCalendar = false
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(palette.control)
                    .frame(width: 42, height: footerHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Add city")

            Spacer()

            settingsMenu
        }
        .padding(.horizontal, 7)
        .frame(height: footerHeight)
        .background(palette.background)
    }

    private var settingsMenu: some View {
        let palette = model.theme.palette

        return ZStack {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 17))
                .foregroundStyle(palette.control)
                .allowsHitTesting(false)

            Menu {
                Menu("Color Theme") {
                    themeButton(.daylight)
                    themeButton(.graphite)
                    themeButton(.midnight)
                }

                Menu("Time Format") {
                    Button {
                        model.uses24HourTime = false
                    } label: {
                        if !model.uses24HourTime {
                            Label("AM / PM", systemImage: "checkmark")
                        } else {
                            Text("AM / PM")
                        }
                    }

                    Button {
                        model.uses24HourTime = true
                    } label: {
                        if model.uses24HourTime {
                            Label("24-Hour", systemImage: "checkmark")
                        } else {
                            Text("24-Hour")
                        }
                    }
                }

                Divider()

                Button(showingCalendar ? "Hide Calendar" : "Calendar Mode") {
                    withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.84)) {
                        showingCalendar.toggle()
                    }
                }

                Divider()

                Button("Quit TZC") {
                    NSApplication.shared.terminate(nil)
                }
            } label: {
                Color.clear
                    .frame(width: 42, height: footerHeight)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .frame(width: 42, height: footerHeight)
        .help("Settings")
    }

    @ViewBuilder
    private func themeButton(_ theme: AppTheme) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                model.theme = theme
            }
        } label: {
            if model.theme == theme {
                Label(theme.title, systemImage: "checkmark")
            } else {
                Text(theme.title)
            }
        }
    }

    private var visibleRowCount: Int {
        min(max(model.zones.count, 1), maximumVisibleRows)
    }

    private var listHeight: CGFloat {
        CGFloat(visibleRowCount) * rowHeight
    }

    private var basePanelHeight: CGFloat {
        timelineHeight + listHeight + footerHeight
    }

    private var panelHeight: CGFloat {
        if showingZonePicker {
            return basePanelHeight
        }
        return basePanelHeight + (showingCalendar ? calendarHeight : 0)
    }

    private func rowReorderGesture(for item: ZoneItem) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                guard let itemIndex = model.zones.firstIndex(where: { $0.id == item.id }) else {
                    return
                }

                if draggingItem == nil {
                    draggingItem = item
                    dragStartIndex = itemIndex
                    dragTargetIndex = itemIndex
                }
                guard draggingItem?.id == item.id else { return }

                let startIndex = dragStartIndex ?? itemIndex
                let rawTarget = startIndex + Int((value.translation.height / rowHeight).rounded())
                let targetIndex = min(max(0, rawTarget), model.zones.count - 1)
                let minimumOffset = -CGFloat(startIndex) * rowHeight
                let maximumOffset = CGFloat(model.zones.count - 1 - startIndex) * rowHeight

                dragTargetIndex = targetIndex
                rowDragOffset = min(max(value.translation.height, minimumOffset), maximumOffset)
            }
            .onEnded { _ in
                guard draggingItem?.id == item.id,
                      let startIndex = dragStartIndex,
                      let targetIndex = dragTargetIndex else {
                    resetDragState()
                    return
                }

                withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.82)) {
                    rowDragOffset = CGFloat(targetIndex - startIndex) * rowHeight
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        model.move(item, to: targetIndex)
                        resetDragState()
                    }
                }
            }
    }

    private func reorderOffset(for item: ZoneItem) -> CGFloat {
        guard let draggedItem = draggingItem,
              let startIndex = dragStartIndex,
              let targetIndex = dragTargetIndex,
              let itemIndex = model.zones.firstIndex(where: { $0.id == item.id }) else {
            return 0
        }

        if item.id == draggedItem.id {
            return rowDragOffset
        }
        if startIndex < targetIndex, itemIndex > startIndex, itemIndex <= targetIndex {
            return -rowHeight
        }
        if targetIndex < startIndex, itemIndex >= targetIndex, itemIndex < startIndex {
            return rowHeight
        }
        return 0
    }

    private func resetDragState() {
        draggingItem = nil
        dragStartIndex = nil
        dragTargetIndex = nil
        rowDragOffset = 0
    }
}

private struct CloneZoneRow: View {
    @EnvironmentObject private var model: AppModel
    let item: ZoneItem
    let showsDivider: Bool
    let date: Date
    let rowHeight: CGFloat
    let remove: () -> Void

    var body: some View {
        let palette = model.theme.palette
        let timeZone = item.timeZone
        let availability = ZoneFormatting.availability(for: date, in: timeZone)
        let timeParts = displayTime(in: timeZone)
        let offset = ZoneFormatting.offsetString(for: date, in: timeZone)
        let timeColor = availability == .sleeping ? palette.sleepy : palette.primary.opacity(0.68)

        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayName)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(palette.primary)
                    .lineLimit(1)

                if offset != "local" {
                    Text(offset)
                        .font(.system(size: 14, weight: .ultraLight))
                        .foregroundStyle(palette.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: -1) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(timeParts.clock)
                        .font(.system(size: 33, weight: .ultraLight))
                        .monospacedDigit()
                        .contentTransition(.numericText())

                    if let period = timeParts.period {
                        Text(period)
                            .font(.system(size: 13.5, weight: .semibold))
                    }
                }
                .foregroundStyle(timeColor)

                HStack(spacing: 6) {
                    Text(ZoneFormatting.dayRelation(for: date, in: timeZone))
                        .font(.system(size: 15.5, weight: .ultraLight))
                        .foregroundStyle(palette.secondary)

                    Image(systemName: availability.symbol)
                        .font(.system(size: availability == .sleeping ? 10 : 9, weight: .semibold))
                        .foregroundStyle(availability.color)
                }
            }
            .frame(minWidth: 122, alignment: .trailing)
        }
        .padding(.leading, 20)
        .padding(.trailing, 18)
        .frame(height: rowHeight)
        .background(palette.background)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            if showsDivider {
                Rectangle()
                    .fill(palette.separator)
                    .frame(height: 0.5)
            }
        }
        .contextMenu {
            Button("Copy Time and Date") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(
                    ZoneFormatting.copyText(
                        for: item,
                        date: date,
                        uses24HourTime: model.uses24HourTime
                    ),
                    forType: .string
                )
            }

            Divider()

            Button("Delete", role: .destructive, action: remove)
        }
    }

    private func displayTime(in timeZone: TimeZone) -> (clock: String, period: String?) {
        let value = ZoneFormatting.timeString(
            for: date,
            in: timeZone,
            uses24HourTime: model.uses24HourTime
        )
        guard !model.uses24HourTime,
              let space = value.lastIndex(of: " ") else {
            return (value, nil)
        }
        return (
            String(value[..<space]),
            String(value[value.index(after: space)...]).uppercased()
        )
    }
}

private struct MiniCalendarView: View {
    @EnvironmentObject private var model: AppModel
    let selectedDate: Date
    @State private var displayedMonth = Date()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let weekdaySymbols = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    var body: some View {
        let palette = model.theme.palette

        VStack(spacing: 4) {
            HStack {
                Button {
                    changeMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                .foregroundStyle(palette.control)

                Spacer()

                Text(monthTitle)
                    .font(.system(size: 15, weight: .ultraLight))
                    .foregroundStyle(palette.primary.opacity(0.72))

                Spacer()

                Button {
                    changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
                .foregroundStyle(palette.control)
            }
            .padding(.horizontal, 18)
            .frame(height: 32)

            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                    Text(symbol)
                        .font(.system(size: 10, weight: .ultraLight))
                        .foregroundStyle(index >= 5 ? Availability.personal.color.opacity(0.72) : palette.secondary)
                        .frame(height: 18)
                }

                ForEach(calendarDays) { day in
                    Button {
                        select(day.date)
                    } label: {
                        Text("\(day.number)")
                            .font(.system(size: 11.5, weight: .light))
                            .foregroundStyle(dayTextColor(day, palette: palette))
                            .frame(width: 23, height: 23)
                            .background {
                                if isSelected(day.date) {
                                    Circle()
                                        .fill(palette.primary.opacity(model.theme == .daylight ? 0.15 : 0.22))
                                } else if isToday(day.date) {
                                    Circle()
                                        .stroke(palette.secondary, lineWidth: 0.7)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 13)
        }
        .padding(.top, 4)
        .background(palette.background)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.separator)
                .frame(height: 0.5)
        }
        .onAppear {
            displayedMonth = selectedDate
        }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    private var calendarDays: [CalendarDay] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        calendar.firstWeekday = 2

        let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: displayedMonth)
        ) ?? displayedMonth
        let weekday = calendar.component(.weekday, from: monthStart)
        let mondayOffset = (weekday + 5) % 7
        let gridStart = calendar.date(byAdding: .day, value: -mondayOffset, to: monthStart) ?? monthStart
        let displayedMonthNumber = calendar.component(.month, from: monthStart)

        return (0..<42).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: gridStart) else {
                return nil
            }
            let weekdayIndex = offset % 7
            return CalendarDay(
                date: date,
                number: calendar.component(.day, from: date),
                isInDisplayedMonth: calendar.component(.month, from: date) == displayedMonthNumber,
                isWeekend: weekdayIndex >= 5
            )
        }
    }

    private func dayTextColor(_ day: CalendarDay, palette: ClonePalette) -> Color {
        let base = day.isWeekend ? Availability.personal.color : palette.primary
        return base.opacity(day.isInDisplayedMonth ? 0.66 : 0.18)
    }

    private func isToday(_ date: Date) -> Bool {
        Calendar.autoupdatingCurrent.isDateInToday(date)
    }

    private func isSelected(_ date: Date) -> Bool {
        Calendar.autoupdatingCurrent.isDate(date, inSameDayAs: selectedDate)
    }

    private func select(_ day: Date) {
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = .autoupdatingCurrent
        let time = calendar.dateComponents([.hour, .minute, .second], from: selectedDate)
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = time.hour
        components.minute = time.minute
        components.second = time.second
        if let combined = calendar.date(from: components) {
            withAnimation(.easeInOut(duration: 0.2)) {
                model.setAnchorDate(combined)
            }
        }
    }

    private func changeMonth(by value: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            displayedMonth = Calendar.autoupdatingCurrent.date(
                byAdding: .month,
                value: value,
                to: displayedMonth
            ) ?? displayedMonth
        }
    }
}

private struct CalendarDay: Identifiable {
    let date: Date
    let number: Int
    let isInDisplayedMonth: Bool
    let isWeekend: Bool

    var id: Date { date }
}
