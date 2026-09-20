import Foundation

struct HolidayEntry: Codable, Equatable {
    enum Kind: String, Codable { case holiday = "public_holiday", workday = "transfer_workday" }
    let date: String
    let name: String
    let type: Kind
}

struct HolidayYear: Codable {
    let year: Int
    let region: String
    let dates: [HolidayEntry]

    static func validated(_ data: Data, expectedYear: Int) throws -> Self {
        let value = try JSONDecoder().decode(Self.self, from: data)
        guard value.region == "CN", value.year == expectedYear, !value.dates.isEmpty,
              value.dates.count <= 150,
              Set(value.dates.map(\.date)).count == value.dates.count,
              value.dates.allSatisfy({ entry in
                  guard let date = CivilDate(iso: entry.date) else { return false }
                  return date.year == expectedYear && !entry.name.isEmpty && entry.name.count < 100
              }) else { throw HolidayError.invalidData }
        return value
    }
}

enum HolidayError: LocalizedError {
    case invalidData, invalidResponse, unavailable
    var errorDescription: String? {
        switch self {
        case .invalidData: return "假期数据格式不正确，已保留原有数据"
        case .invalidResponse: return "无法连接假期数据源，已保留原有数据"
        case .unavailable: return "该年份的放假安排尚未收录"
        }
    }
}
