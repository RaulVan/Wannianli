import SwiftUI

struct MenuCalendar: View {
    @ObservedObject var state: CalendarState
    @ObservedObject var holidays: HolidayStore
    @ObservedObject var calendarEvents: LocalCalendarStore
    let openWindow: () -> Void
    let openSettings: () -> Void
    let checkForUpdates: () -> Void
    var canCheckForUpdates = true
    var panelHeight: CGFloat = Design.panelHeight

    static let monthGridHeight: CGFloat = 332
    static let compactEventRowHeight: CGFloat = 24
    static let maximumVisibleEventRows = 4

    static func eventSectionHeight(eventCount: Int, accessState: LocalCalendarStore.AccessState) -> CGFloat {
        if accessState != .granted { return 28 }
        return CGFloat(min(eventCount, maximumVisibleEventRows)) * compactEventRowHeight
    }

    static func preferredPanelHeight(eventCount: Int, accessState: LocalCalendarStore.AccessState) -> CGFloat {
        Design.panelHeight + eventSectionHeight(eventCount: eventCount, accessState: accessState)
    }

    var body: some View {
        VStack(spacing: 12) {
            MonthNavigation(state: state, compact: true).frame(height: 34)
            MonthGrid(state: state, holidays: holidays, compact: true)
                .frame(height: Self.monthGridHeight)
            Hairline()
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(state.detail.lunarTitle).font(Design.lunarFont(26))
                Text("\(state.detail.lunar.yearInGanZhi)年 · \(state.detail.lunar.yearShengXiao)")
                    .font(.system(size: 14)).foregroundStyle(Design.secondary)
                Spacer(minLength: 0)
            }.foregroundStyle(Design.ink).frame(height: 34)
            VStack(spacing: 10) {
                AuspiceRow(title: "宜", items: state.detail.lunar.dayYi, compact: true)
                AuspiceRow(title: "忌", items: state.detail.lunar.dayJi, compact: true)
            }.frame(height: 66)
            Hairline()
            FestivalCard(
                state: state,
                calendarEvents: calendarEvents,
                compact: true,
                compactEventHeight: max(0, panelHeight - Design.panelHeight)
            )
            HStack(spacing: 12) {
                Button(action: openWindow) {
                    Text("打开完整日历").frame(maxWidth: .infinity).frame(height: 35)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Design.line, lineWidth: 1))
                }.buttonStyle(.plain).accessibilityIdentifier("openFullCalendar")
                Menu {
                    Button("设置…", action: openSettings)
                    Button("更新放假安排") { Task { await holidays.refresh(year: state.year, force: true) } }
                    Button("检查软件更新…", action: checkForUpdates)
                        .disabled(!canCheckForUpdates)
                    Divider()
                    Button("退出万年历") { NSApp.terminate(nil) }
                } label: { Image(systemName: "gearshape").font(.system(size: 19)) }
                .menuStyle(.borderlessButton).fixedSize().accessibilityIdentifier("menuSettings")
            }
        }.padding(18).frame(width: Design.panelWidth, height: panelHeight)
            .background(Design.background).foregroundStyle(Design.ink)
            .onChange(of: state.year) { _, year in Task { await holidays.refresh(year: year) } }
    }

}
