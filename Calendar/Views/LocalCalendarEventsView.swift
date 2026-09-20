import SwiftUI

struct LocalCalendarEventsView: View {
    @ObservedObject var store: LocalCalendarStore
    var compact = false
    var compactHeight: CGFloat? = nil

    private var visibleEvents: ArraySlice<LocalCalendarEvent> {
        store.events.prefix(compact ? 3 : 5)
    }

    var body: some View {
        Group {
            switch store.accessState {
            case .granted where store.events.isEmpty:
                EmptyView()
            case .granted:
                compact ? AnyView(compactEventList) : AnyView(eventList)
            case .notDetermined:
                permissionButton(title: "显示 Apple 日历事件", detail: "允许读取本地日历")
            case .requesting:
                statusRow(symbol: "calendar.badge.clock", title: "正在请求日历权限…")
            case .denied:
                permissionButton(title: "日历权限已关闭", detail: "前往系统设置开启")
            case .restricted:
                statusRow(symbol: "calendar.badge.exclamationmark", title: "此 Mac 限制访问日历")
            case .failed(let message):
                statusRow(symbol: "exclamationmark.triangle", title: message)
            }
        }
        .accessibilityIdentifier("localCalendarEvents")
        .frame(height: compact ? compactHeight : nil)
        .clipped()
    }

    private var compactEventList: some View {
        ScrollView(.vertical, showsIndicators: store.events.count > MenuCalendar.maximumVisibleEventRows) {
            LazyVStack(spacing: 6) {
                ForEach(store.events) { event in
                    eventRow(event)
                        .frame(height: 18)
                }
            }
        }
    }

    private var eventList: some View {
        VStack(spacing: compact ? 6 : 8) {
            ForEach(visibleEvents) { event in
                eventRow(event)
            }
            if store.events.count > visibleEvents.count {
                Text("另有 \(store.events.count - visibleEvents.count) 个事件")
                    .font(.system(size: compact ? 10 : 12)).foregroundStyle(Design.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func eventRow(_ event: LocalCalendarEvent) -> some View {
        HStack(spacing: compact ? 8 : 12) {
            Circle()
                .fill(Color(nsColor: event.calendarColor))
                .frame(width: compact ? 7 : 9, height: compact ? 7 : 9)
            Text(timeText(for: event))
                .font(.system(size: compact ? 11 : 14, weight: .medium))
                .foregroundStyle(Design.secondary)
                .frame(width: compact ? 48 : 62, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: compact ? 12 : 15, weight: .medium))
                    .foregroundStyle(Design.ink)
                    .lineLimit(1)
                if !compact {
                    Text([event.calendarTitle, event.location].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 11)).foregroundStyle(Design.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func permissionButton(title: String, detail: String) -> some View {
        Button {
            Task { await store.requestAccess() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "calendar.badge.plus").foregroundStyle(Design.red)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: compact ? 12 : 15, weight: .medium))
                    if !compact { Text(detail).font(.system(size: 11)).foregroundStyle(Design.secondary) }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(Design.secondary)
            }
        }.buttonStyle(.plain)
    }

    private func statusRow(symbol: String, title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).foregroundStyle(Design.red)
            Text(title).font(.system(size: compact ? 12 : 14)).lineLimit(1)
            Spacer()
        }.foregroundStyle(Design.secondary)
    }

    private func timeText(for event: LocalCalendarEvent) -> String {
        if event.isAllDay { return "全天" }
        return event.startDate.formatted(date: .omitted, time: .shortened)
    }
}
