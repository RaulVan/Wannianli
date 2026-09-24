import Foundation
import SwiftUI
import WidgetKit

struct CalendarWidgetEntry: TimelineEntry {
    let date: Date
    let day: AlmanacDay
}

struct CalendarWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> CalendarWidgetEntry {
        entry(for: CivilDate(year: 2026, month: 9, day: 24), at: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (CalendarWidgetEntry) -> Void) {
        let date = context.isPreview ? CivilDate(year: 2026, month: 9, day: 24) : CivilDate(Date())
        completion(entry(for: date, at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CalendarWidgetEntry>) -> Void) {
        let now = Date()
        let civil = CivilDate(now)
        let current = entry(for: civil, at: now)
        let nextUpdate = nextMidnight(after: now)
        completion(Timeline(entries: [current], policy: .after(nextUpdate)))
    }

    private func entry(for date: CivilDate, at timelineDate: Date) -> CalendarWidgetEntry {
        CalendarWidgetEntry(date: timelineDate, day: CalendarEngine().day(date))
    }

    private func nextMidnight(after date: Date) -> Date {
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = .current
        let startOfToday = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: startOfToday)
            ?? date.addingTimeInterval(24 * 60 * 60)
    }
}

struct CalendarWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    let entry: CalendarWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallCalendarWidget(day: entry.day, colorScheme: colorScheme)
            case .systemLarge:
                LargeCalendarWidget(day: entry.day, colorScheme: colorScheme)
            default:
                MediumCalendarWidget(day: entry.day, colorScheme: colorScheme)
            }
        }
        .containerBackground(for: .widget) {
            WidgetDesign.background(for: colorScheme)
        }
    }
}

private struct SmallCalendarWidget: View {
    let day: AlmanacDay
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 0) {
            WidgetDateHeader(day: day, colorScheme: colorScheme, fontSize: 9)
            Spacer(minLength: 0)
            Text(verbatim: String(day.civil.day))
                .font(.system(size: 42, weight: .medium, design: .serif))
                .foregroundStyle(WidgetDesign.red(for: colorScheme))
                .lineLimit(1)
            Text(day.lunarTitle)
                .font(WidgetDesign.lunarFont(15))
                .foregroundStyle(WidgetDesign.red(for: colorScheme))
                .lineLimit(1)
            Text("\(day.lunar.yearInGanZhi)年 · \(day.lunar.yearShengXiao)")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(WidgetDesign.secondary(for: colorScheme))
                .lineLimit(1)
            Spacer(minLength: 0)
            Rectangle()
                .fill(WidgetDesign.line(for: colorScheme))
                .frame(height: 1)
                .padding(.bottom, 5)
            WidgetAuspiceRow(title: "宜", items: day.lunar.dayYi, size: .small, colorScheme: colorScheme)
                .padding(.bottom, 3)
            WidgetAuspiceRow(title: "忌", items: day.lunar.dayJi, size: .small, colorScheme: colorScheme)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(widgetAccessibilityLabel)
    }

    private var widgetAccessibilityLabel: String {
        "\(day.civil.year)年\(day.civil.month)月\(day.civil.day)日，\(day.lunarTitle)，宜\(day.lunar.dayYi.joined(separator: "、"))，忌\(day.lunar.dayJi.joined(separator: "、"))"
    }
}

private struct MediumCalendarWidget: View {
    let day: AlmanacDay
    let colorScheme: ColorScheme

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(spacing: 0) {
                WidgetDateHeader(day: day, colorScheme: colorScheme, fontSize: 12)
                Text(verbatim: String(day.civil.day))
                    .font(.system(size: 58, weight: .medium, design: .serif))
                    .foregroundStyle(WidgetDesign.red(for: colorScheme))
                    .lineLimit(1)
                Text(day.lunarTitle)
                    .font(WidgetDesign.lunarFont(21))
                    .foregroundStyle(WidgetDesign.red(for: colorScheme))
                    .lineLimit(1)
                Text("\(day.lunar.yearInGanZhi)年 · \(day.lunar.yearShengXiao)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(WidgetDesign.secondary(for: colorScheme))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(WidgetDesign.line(for: colorScheme))
                .frame(width: 1)

            VStack(alignment: .leading, spacing: 12) {
                WidgetAuspiceRow(title: "宜", items: day.lunar.dayYi, size: .medium, colorScheme: colorScheme)
                WidgetAuspiceRow(title: "忌", items: day.lunar.dayJi, size: .medium, colorScheme: colorScheme)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(day.civil.year)年\(day.civil.month)月\(day.civil.day)日，\(day.lunarTitle)，宜\(day.lunar.dayYi.joined(separator: "、"))，忌\(day.lunar.dayJi.joined(separator: "、"))")
    }
}

private struct LargeCalendarWidget: View {
    let day: AlmanacDay
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 0) {
            WidgetDateHeader(day: day, colorScheme: colorScheme, fontSize: 15)
            Spacer(minLength: 4)
            Text(verbatim: String(day.civil.day))
                .font(.system(size: 90, weight: .medium, design: .serif))
                .foregroundStyle(WidgetDesign.red(for: colorScheme))
                .lineLimit(1)
            Text(day.lunarTitle)
                .font(WidgetDesign.lunarFont(28))
                .foregroundStyle(WidgetDesign.red(for: colorScheme))
                .lineLimit(1)
            Text("\(day.lunar.yearInGanZhi)年 · \(day.lunar.yearShengXiao)")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(WidgetDesign.secondary(for: colorScheme))
            Spacer(minLength: 14)
            Rectangle()
                .fill(WidgetDesign.line(for: colorScheme))
                .frame(height: 1)
            Spacer(minLength: 14)
            VStack(spacing: 12) {
                WidgetAuspiceRow(title: "宜", items: day.lunar.dayYi, size: .large, colorScheme: colorScheme)
                WidgetAuspiceRow(title: "忌", items: day.lunar.dayJi, size: .large, colorScheme: colorScheme)
            }
        }
        .padding(26)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(day.civil.year)年\(day.civil.month)月\(day.civil.day)日，\(day.lunarTitle)，宜\(day.lunar.dayYi.joined(separator: "、"))，忌\(day.lunar.dayJi.joined(separator: "、"))")
    }
}

private struct WidgetDateHeader: View {
    let day: AlmanacDay
    let colorScheme: ColorScheme
    let fontSize: CGFloat

    var body: some View {
        Text(verbatim: "\(day.civil.year)年\(day.civil.month)月\(day.civil.day)日  \(day.weekday)")
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundStyle(WidgetDesign.ink(for: colorScheme))
            .lineLimit(1)
            .minimumScaleFactor(0.9)
            .frame(maxWidth: .infinity)
    }
}

private struct WidgetAuspiceRow: View {
    enum Size {
        case small, medium, large

        var badge: CGFloat {
            switch self {
            case .small: 20
            case .medium: 32
            case .large: 34
            }
        }

        var text: CGFloat {
            switch self {
            case .small: 10
            case .medium: 14
            case .large: 16
            }
        }
    }

    let title: String
    let items: [String]
    let size: Size
    let colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: size == .small ? 6 : 10) {
            Text(title)
                .font(.system(size: size.badge / 2, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size.badge, height: size.badge)
                .background(title == "宜" ? WidgetDesign.badgeGreen(for: colorScheme) : WidgetDesign.badgeRed(for: colorScheme), in: RoundedRectangle(cornerRadius: size == .small ? 6 : 9))
            Text(summary)
                .font(.system(size: size.text, weight: .medium))
                .foregroundStyle(WidgetDesign.ink(for: colorScheme))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summary: String {
        let value = items.isEmpty ? "无" : items.joined(separator: " ")
        return value
    }
}

@main
struct CalendarWidget: Widget {
    private let kind = "WannianliWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CalendarWidgetProvider()) { entry in
            CalendarWidgetView(entry: entry)
        }
        .configurationDisplayName("万年历")
        .description("查看今日公历、农历、干支与宜忌。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
