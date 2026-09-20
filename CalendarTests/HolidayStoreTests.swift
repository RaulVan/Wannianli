import XCTest
@testable import Wannianli

private final class HolidayProtocol: URLProtocol {
    static var invalidYear = false
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let body: String
        if request.url!.lastPathComponent == "index.json" {
            body = #"{"regions":[{"name":"CN","startYear":2025,"endYear":2026}]}"#
        } else if Self.invalidYear {
            body = #"{"year":2026,"region":"CN","dates":[]}"#
        } else {
            body = #"{"year":2026,"region":"CN","dates":[{"date":"2026-09-25","name":"中秋节","type":"public_holiday"},{"date":"2026-09-20","name":"国庆节补班","type":"transfer_workday"}]}"#
        }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class HolidayStoreTests: XCTestCase {
    @MainActor func testRefreshCacheAndRejectInvalidReplacement() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [HolidayProtocol.self]
        let session = URLSession(configuration: config)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("CalendarTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        HolidayProtocol.invalidYear = false
        let store = HolidayStore(directory: directory, session: session)
        await store.refresh(year: 2026, force: true)
        XCTAssertEqual(store.message, "已更新放假安排")
        XCTAssertEqual(store.years[2026]?.dates.count, 2)
        let reloaded = HolidayStore(directory: directory, session: session)
        XCTAssertEqual(reloaded.years[2026]?.dates.count, 2)
        XCTAssertNotNil(reloaded.lastUpdated)
        HolidayProtocol.invalidYear = true
        await store.refresh(year: 2026, force: true)
        XCTAssertEqual(store.years[2026]?.dates.count, 2)
        XCTAssertTrue(store.message.contains("保留"))
        await store.refresh(year: 2099, force: true)
        XCTAssertFalse(store.hasYear(2099))
        XCTAssertTrue(store.message.contains("尚未收录"))
        HolidayProtocol.invalidYear = false
    }
}
