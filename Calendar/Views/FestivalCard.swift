import SwiftUI

struct FestivalCard: View {
    @ObservedObject var state: CalendarState
    @ObservedObject var calendarEvents: LocalCalendarStore
    var compact = false
    var compactEventHeight: CGFloat? = nil
    var body: some View {
        VStack(spacing: compact ? 9 : 12) {
            LocalCalendarEventsView(
                store: calendarEvents,
                compact: compact,
                compactHeight: compactEventHeight
            )
            if let event = state.upcoming {
                Button { state.select(event.date) } label: {
                    HStack(spacing: compact ? 9 : 22) {
                        Image(systemName: "calendar").font(.system(size: compact ? 19 : 38)).foregroundStyle(Design.red)
                        VStack(alignment: .leading, spacing: 5) {
                            if !compact { Text(event.name).font(.system(size: 22, weight: .semibold)).foregroundStyle(Design.ink) }
                            (Text("距离\(event.name)还有 ").foregroundColor(Design.secondary)
                             + Text("\(state.today.days(until: event.date))").foregroundColor(Design.red)
                             + Text(" 天").foregroundColor(Design.secondary))
                                .font(.system(size: compact ? 13 : 17))
                        }
                        Spacer(minLength: 2)
                        Text("\(String(event.date.year))年\(event.date.month)月\(event.date.day)日")
                            .font(.system(size: compact ? 12 : 17)).foregroundStyle(Design.secondary)
                        if !compact { Image(systemName: "chevron.right").foregroundStyle(Design.secondary) }
                    }
                    .padding(compact ? 0 : 21)
                    .frame(maxWidth: .infinity, minHeight: compact ? 37 : 88)
                    .background(compact ? Color.clear : Design.surface, in: RoundedRectangle(cornerRadius: 15))
                }.buttonStyle(.plain).accessibilityIdentifier("nextFestival")
            }
        }
    }
}
