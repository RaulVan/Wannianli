import Foundation
import LunarSwift

final class CalendarEngine {
    private var cache: [CivilDate: AlmanacDay] = [:]

    func day(_ date: CivilDate) -> AlmanacDay {
        if let cached = cache[date] { return cached }
        let solar = Solar(year: date.year, month: date.month, day: date.day)
        let lunar = solar.lunar
        let festivals = lunar.festivals + solar.festivals
        let result = AlmanacDay(civil: date, lunar: lunar, festivals: festivals)
        if cache.count > 900 { cache.removeAll(keepingCapacity: true) }
        cache[date] = result
        return result
    }

    func month(year: Int, month: Int, mondayFirst: Bool) -> [AlmanacDay] {
        let first = CivilDate(year: year, month: month, day: 1)
        let offset = (first.weekday - (mondayFirst ? 2 : 1) + 7) % 7
        return (0..<42).map { day(first.adding(days: $0 - offset)) }
    }

    func nextFestival(after today: CivilDate) -> (name: String, date: CivilDate)? {
        let major: Set<String> = ["元旦节", "元旦", "春节", "元宵节", "清明节", "劳动节", "端午节", "中秋节", "国庆节", "重阳节", "除夕"]
        for offset in 0...370 {
            let date = today.adding(days: offset)
            guard date.supported else { break }
            let info = day(date)
            if let name = info.festivals.first(where: { major.contains($0) }) { return (name, date) }
            if info.lunar.jieQi == "清明" { return ("清明节", date) }
        }
        return nil
    }
}
