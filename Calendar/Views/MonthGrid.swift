import SwiftUI

struct MonthGrid: View {
    @ObservedObject var state: CalendarState
    @ObservedObject var holidays: HolidayStore
    var compact = false
    private var weekdays: [String] {
        state.mondayFirst ? ["一", "二", "三", "四", "五", "六", "日"] : ["日", "一", "二", "三", "四", "五", "六"]
    }
    private var mouseSwipe: some Gesture {
        DragGesture(minimumDistance: 45)
            .onEnded { value in
                let horizontal = abs(value.translation.width) > abs(value.translation.height) * 1.25
                guard horizontal else { return }
                changeMonth(value.translation.width < 0 ? 1 : -1)
            }
    }

    private func changeMonth(_ delta: Int) {
        withAnimation(.easeOut(duration: 0.16)) {
            state.changeMonth(delta)
        }
    }

    var body: some View {
        VStack(spacing: compact ? 9 : 17) {
            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day).font(.system(size: compact ? 13 : 15))
                        .foregroundStyle(day == "六" || day == "日" ? Design.red : Design.secondary)
                        .frame(maxWidth: .infinity)
                }
            }.frame(height: compact ? 22 : 28)
            GeometryReader { geometry in
                let gap: CGFloat = compact ? 5 : 10
                let height = (geometry.size.height - gap * 5) / 6
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: compact ? 3 : 7), count: 7), spacing: gap) {
                    ForEach(state.days) { day in
                        DayCell(day: day, selected: day.civil == state.selected,
                                today: day.civil == state.today, inMonth: day.civil.month == state.month,
                                holiday: holidays.entry(day.civil), compact: compact) {
                            state.select(day.civil)
                        }.frame(height: height)
                    }
                }
            }
        }
        .background(HorizontalMonthSwipeMonitor(onMonthChange: changeMonth))
        .simultaneousGesture(mouseSwipe)
        .accessibilityIdentifier(compact ? "menuMonthGrid" : "monthGrid")
    }
}

private struct DayCell: View {
    let day: AlmanacDay
    let selected: Bool
    let today: Bool
    let inMonth: Bool
    let holiday: HolidayEntry?
    let compact: Bool
    let action: () -> Void
    @State private var hovering = false

    private var textColor: Color {
        if selected { return .white }
        if holiday?.type == .workday { return Design.ink }
        if holiday?.type == .holiday { return Design.red }
        if !inMonth { return day.civil.isWeekend ? Design.red.opacity(0.35) : Design.muted }
        return day.civil.isWeekend ? Design.red : Design.ink
    }
    var body: some View {
        Button(action: action) {
            VStack(spacing: compact ? 2 : 3) {
                Text("\(day.civil.day)")
                    .font(.system(size: compact ? 21 : 30, weight: .medium))
                    .monospacedDigit()
                Text(day.subtitle).font(.system(size: compact ? 10 : 15))
                    .lineLimit(1).minimumScaleFactor(0.75)
                    .foregroundStyle(selected ? .white : textColor == Design.ink ? Design.secondary : textColor)
            }
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(selected ? Design.selection : holiday?.type == .holiday ? Design.holiday : hovering ? Design.surface : Color.clear,
                        in: RoundedRectangle(cornerRadius: compact ? 10 : 14))
            .overlay {
                if today && !selected {
                    RoundedRectangle(cornerRadius: compact ? 10 : 14).stroke(Design.red, lineWidth: 1.5)
                }
            }
            .overlay(alignment: .topTrailing) {
                if let holiday {
                    Text(holiday.type == .holiday ? "休" : "班")
                        .font(.system(size: compact ? 10 : 13, weight: .medium))
                        .foregroundStyle(.white).padding(.horizontal, compact ? 2 : 3).padding(.vertical, 1)
                        .background(holiday.type == .holiday ? Design.selection : Design.badge,
                                    in: RoundedRectangle(cornerRadius: 4))
                        .offset(x: 1, y: -1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!day.civil.supported)
        .onHover { hovering = $0 }
        .help("\(day.civil.id) \(day.lunarTitle) \(day.festivals.joined(separator: "、")) \(holiday?.name ?? "")")
        .accessibilityLabel("\(day.civil.id) \(day.lunarTitle) \(holiday?.type == .holiday ? "休假" : holiday?.type == .workday ? "补班" : "")")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("day-\(day.civil.id)")
    }
}
