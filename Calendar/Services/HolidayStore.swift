import Foundation

@MainActor
final class HolidayStore: ObservableObject {
    @Published private(set) var years: [Int: HolidayYear] = [:]
    @Published private(set) var isRefreshing = false
    @Published private(set) var message = "已载入离线放假安排"
    @Published private(set) var lastUpdated: Date?
    private let directory: URL
    private let session: URLSession
    private var entries: [String: HolidayEntry] = [:]
    private var attempted: [Int: Date] = [:]
    private let base = URL(string: "https://raw.githubusercontent.com/cg-zhou/holiday-calendar/main/data/")!

    init(directory: URL? = nil, session: URLSession = .shared) {
        self.session = session
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Wannianli/Holidays", isDirectory: true)
        for year in [2025, 2026] {
            if let url = Bundle.main.url(forResource: "CN-\(year)", withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let value = try? HolidayYear.validated(data, expectedYear: year) { years[year] = value }
        }
        let files = (try? FileManager.default.contentsOfDirectory(at: self.directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        for file in files where file.pathExtension == "json" {
            guard let year = Int(file.deletingPathExtension().lastPathComponent),
                  let data = try? Data(contentsOf: file),
                  let value = try? HolidayYear.validated(data, expectedYear: year) else { continue }
            years[year] = value
            if let modified = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
                attempted[year] = modified
                lastUpdated = max(lastUpdated ?? .distantPast, modified)
            }
        }
        rebuildEntries()
        if lastUpdated != nil { message = "已载入缓存放假安排" }
    }

    func entry(_ date: CivilDate) -> HolidayEntry? { entries[date.id] }
    func hasYear(_ year: Int) -> Bool { years[year] != nil }

    func refresh(year: Int, force: Bool = false) async {
        guard !isRefreshing else { return }
        if !force, let previous = attempted[year], Date().timeIntervalSince(previous) < 86_400 { return }
        attempted[year] = Date()
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            struct Index: Decodable {
                struct Region: Decodable { let name: String; let startYear: Int; let endYear: Int }
                let regions: [Region]
            }
            let indexData = try await fetch(base.appendingPathComponent("index.json"))
            let index = try JSONDecoder().decode(Index.self, from: indexData)
            guard let cn = index.regions.first(where: { $0.name == "CN" }),
                  cn.startYear <= cn.endYear,
                  (cn.startYear...cn.endYear).contains(year) else { throw HolidayError.unavailable }
            let data = try await fetch(base.appendingPathComponent("CN/\(year).json"))
            let value = try HolidayYear.validated(data, expectedYear: year)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: directory.appendingPathComponent("\(year).json"), options: .atomic)
            years[year] = value
            rebuildEntries()
            lastUpdated = Date()
            message = "已更新放假安排"
        } catch {
            message = (error as? HolidayError)?.localizedDescription ?? "更新失败，继续使用离线数据"
        }
    }

    private func fetch(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200, data.count < 1_000_000 else {
            throw HolidayError.invalidResponse
        }
        return data
    }

    private func rebuildEntries() {
        entries = Dictionary(years.values.flatMap(\.dates).map { ($0.date, $0) }, uniquingKeysWith: { _, new in new })
    }
}
