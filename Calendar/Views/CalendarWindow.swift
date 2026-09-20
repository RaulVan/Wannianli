import SwiftUI

struct CalendarWindow: View {
    @ObservedObject var state: CalendarState
    @ObservedObject var holidays: HolidayStore
    @ObservedObject var calendarEvents: LocalCalendarStore
    let openSettings: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    VStack(spacing: 22) {
                        MonthNavigation(state: state).frame(height: 48)
                        MonthGrid(state: state, holidays: holidays)
                        FestivalCard(state: state, calendarEvents: calendarEvents)
                    }.padding(.horizontal, 28).padding(.top, 26).padding(.bottom, 14)
                        .frame(width: geometry.size.width * 0.654)
                    Rectangle().fill(Design.line).frame(width: 1)
                    AlmanacDetail(day: state.detail).frame(maxWidth: .infinity)
                }
            }
            Hairline()
            HStack(spacing: 9) {
                Button {
                    Task { await holidays.refresh(year: state.year, force: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }.buttonStyle(.plain).disabled(holidays.isRefreshing).help("更新放假安排")
                    .accessibilityIdentifier("refreshHolidays")
                Text(holidays.isRefreshing ? "正在更新放假安排…" : holidays.hasYear(state.year) ? holidays.message : "暂无\(String(state.year))年放假安排")
                    .font(.system(size: 14)).accessibilityIdentifier("holidayStatus")
                Spacer()
                IconButton(symbol: "gearshape", label: "设置", action: openSettings)
            }.foregroundStyle(Design.secondary).padding(.horizontal, 29).frame(height: 49)
        }
        .background(Design.background)
        .frame(minWidth: 920, minHeight: 720)
        .onChange(of: state.year) { _, year in Task { await holidays.refresh(year: year) } }
    }
}
