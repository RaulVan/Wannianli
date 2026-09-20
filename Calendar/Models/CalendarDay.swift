import Foundation
import LunarSwift

/// A civil date, independent of an instant's time zone.
struct CivilDate: Hashable, Comparable, Codable, Identifiable {
    let year: Int
    let month: Int
    let day: Int
    var id: String { String(format: "%04d-%02d-%02d", year, month, day) }
    static let minimum = CivilDate(year: 1901, month: 1, day: 1)
    static let maximum = CivilDate(year: 2100, month: 12, day: 31)
    static var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }
    var date: Date {
        Self.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }
    var weekday: Int { Self.calendar.component(.weekday, from: date) }
    var isWeekend: Bool { weekday == 1 || weekday == 7 }
    var supported: Bool { self >= Self.minimum && self <= Self.maximum }
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.id < rhs.id }
    init(year: Int, month: Int, day: Int) {
        self.year = year; self.month = month; self.day = day
    }
    init(_ date: Date, timeZone: TimeZone = .current) {
        var calendar = Self.calendar
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year!, month: parts.month!, day: parts.day!)
    }
    init?(iso: String) {
        let parts = iso.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1901...2100).contains(parts[0]),
              (1...12).contains(parts[1]), (1...31).contains(parts[2]) else { return nil }
        self.init(year: parts[0], month: parts[1], day: parts[2])
        guard CivilDate(date, timeZone: .gmt) == self else { return nil }
    }
    func adding(days: Int) -> Self {
        Self(Self.calendar.date(byAdding: .day, value: days, to: date)!, timeZone: .gmt)
    }
    func days(until other: Self) -> Int {
        Self.calendar.dateComponents([.day], from: date, to: other.date).day!
    }
}

struct AlmanacDay: Identifiable {
    let civil: CivilDate
    let lunar: Lunar
    let festivals: [String]
    var id: String { civil.id }
    var lunarTitle: String { lunar.monthInChinese + "月" + lunar.dayInChinese }
    var subtitle: String {
        let prominent: Set<String> = ["元旦", "元旦节", "春节", "元宵节", "除夕", "清明节", "劳动节", "端午节", "七夕节", "中秋节", "重阳节", "国庆节", "教师节", "妇女节", "儿童节", "建军节", "建党节"]
        return festivals.first(where: { prominent.contains($0) })
            ?? (lunar.jieQi.isEmpty ? lunar.dayInChinese : lunar.jieQi)
    }
    var weekday: String { "星期" + ["日", "一", "二", "三", "四", "五", "六"][civil.weekday - 1] }
}
