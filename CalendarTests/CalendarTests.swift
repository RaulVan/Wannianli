import XCTest
import AppKit
@testable import Wannianli

final class CalendarTests: XCTestCase {
    let engine = CalendarEngine()
    func testKnownLunarDates() {
        let midAutumn = engine.day(CivilDate(year: 2026, month: 9, day: 25))
        XCTAssertEqual(midAutumn.lunarTitle, "八月十五")
        XCTAssertTrue(midAutumn.festivals.contains("中秋节"))
        let newYear = engine.day(CivilDate(year: 2026, month: 2, day: 17))
        XCTAssertEqual(newYear.lunarTitle, "正月初一")
        XCTAssertTrue(newYear.festivals.contains("春节"))
        XCTAssertEqual(engine.day(CivilDate(year: 2026, month: 9, day: 7)).lunar.jieQi, "白露")
        XCTAssertEqual(engine.day(CivilDate(year: 2025, month: 7, day: 25)).lunar.month, -6)
    }
    func testMonthGridAndDateBoundaries() {
        let days = engine.month(year: 2026, month: 9, mondayFirst: true)
        XCTAssertEqual(days.count, 42)
        XCTAssertEqual(days.first?.civil.id, "2026-08-31")
        XCTAssertEqual(days.last?.civil.id, "2026-10-11")
        XCTAssertEqual(Set(days.map(\.id)).count, 42)
        XCTAssertEqual(engine.month(year: 2026, month: 9, mondayFirst: false).first?.civil.id, "2026-08-30")
        XCTAssertEqual(CivilDate(year: 2024, month: 2, day: 28).adding(days: 1).id, "2024-02-29")
        XCTAssertEqual(CivilDate(year: 2026, month: 12, day: 31).adding(days: 1).id, "2027-01-01")
        XCTAssertNil(CivilDate(iso: "2026-02-30"))
    }
    func testFestivalCountdown() {
        let today = CivilDate(year: 2026, month: 9, day: 19)
        let festival = engine.nextFestival(after: today)
        XCTAssertEqual(festival?.name, "中秋节")
        XCTAssertEqual(today.days(until: festival!.date), 6)
    }
    func testInvalidHolidayDataRejected() {
        XCTAssertThrowsError(try HolidayYear.validated(Data(#"{"year":2026,"region":"US","dates":[]}"#.utf8), expectedYear: 2026))
        XCTAssertThrowsError(try HolidayYear.validated(Data(#"{"year":2026,"region":"CN","dates":[{"date":"2026-02-30","name":"假期","type":"public_holiday"}]}"#.utf8), expectedYear: 2026))
    }
    @MainActor func testBuiltInHolidayAndUnknownYear() {
        let store = HolidayStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        XCTAssertEqual(store.entry(CivilDate(year: 2026, month: 9, day: 25))?.type, .holiday)
        XCTAssertEqual(store.entry(CivilDate(year: 2026, month: 9, day: 20))?.type, .workday)
        XCTAssertFalse(store.hasYear(2099))
    }
    @MainActor func testClockDoesNotResetHistoricalSelection() {
        let defaults = UserDefaults(suiteName: "CalendarTests.\(UUID().uuidString)")!
        let state = CalendarState(defaults: defaults, now: CivilDate(year: 2026, month: 9, day: 19).date)
        state.select(CivilDate(year: 2024, month: 2, day: 29))
        state.refreshClock(now: CivilDate(year: 2026, month: 9, day: 20).date)
        XCTAssertEqual(state.selected.id, "2024-02-29")
        state.setMonth(year: 2025, month: 2)
        XCTAssertEqual(state.selected.id, "2025-02-28")
    }
    @MainActor func testGoTodayReturnsToCurrentSystemDateAfterBrowsing() {
        let defaults = UserDefaults(suiteName: "CalendarTests.\(UUID().uuidString)")!
        let current = CivilDate(year: 2026, month: 9, day: 19)
        let state = CalendarState(defaults: defaults, now: current.date)
        state.select(CivilDate(year: 2026, month: 9, day: 3))

        state.goToday(now: current.date)

        XCTAssertEqual(state.today.id, "2026-09-19")
        XCTAssertEqual(state.selected.id, "2026-09-19")
        XCTAssertEqual(state.year, 2026)
        XCTAssertEqual(state.month, 9)
    }
    @MainActor func testLocalCalendarQueryUsesTheSelectedLocalDay() {
        let timeZone = TimeZone(identifier: "Asia/Singapore")!
        let interval = LocalCalendarStore.dayInterval(
            for: CivilDate(year: 2026, month: 9, day: 20),
            timeZone: timeZone
        )
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        XCTAssertEqual(calendar.dateComponents([.year, .month, .day, .hour], from: interval.start),
                       DateComponents(year: 2026, month: 9, day: 20, hour: 0))
        XCTAssertEqual(interval.duration, 24 * 60 * 60)
    }
    @MainActor func testMenuPanelGrowsWithoutReducingMonthGridHeight() {
        XCTAssertEqual(MenuCalendar.monthGridHeight, 332)
        XCTAssertEqual(
            MenuCalendar.preferredPanelHeight(eventCount: 3, accessState: .granted),
            Design.panelHeight + 72
        )
    }
    @MainActor func testMenuPanelCapsEventGrowthAtFourRows() {
        let fourEvents = MenuCalendar.preferredPanelHeight(eventCount: 4, accessState: .granted)
        let manyEvents = MenuCalendar.preferredPanelHeight(eventCount: 20, accessState: .granted)
        XCTAssertEqual(manyEvents, fourEvents)
        XCTAssertEqual(manyEvents, Design.panelHeight + 96)
    }
    @MainActor func testMenuPanelUsesNewlyPublishedEventCount() {
        let publishedEventCount = 2
        let height = MenuCalendar.preferredPanelHeight(
            eventCount: publishedEventCount,
            accessState: .granted
        )

        XCTAssertEqual(height, Design.panelHeight + 48)
    }
    func testDynamicAppIconRendersEveryValidDay() throws {
        let baseURL = try XCTUnwrap(Bundle(for: AppDelegate.self).url(forResource: "calendar-base", withExtension: "png"))
        let base = try XCTUnwrap(NSImage(contentsOf: baseURL))
        let first = try XCTUnwrap(DynamicAppIconRenderer.render(day: 1, baseImage: base))
        let third = try XCTUnwrap(DynamicAppIconRenderer.render(day: 3, baseImage: base))
        let twelfth = try XCTUnwrap(DynamicAppIconRenderer.render(day: 12, baseImage: base))
        let thirtyFirst = try XCTUnwrap(DynamicAppIconRenderer.render(day: 31, baseImage: base))
        XCTAssertEqual(first.size, base.size)
        XCTAssertEqual(thirtyFirst.size, base.size)
        XCTAssertNotEqual(first.tiffRepresentation, third.tiffRepresentation)
        let bitmap = try XCTUnwrap(first.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:)))
        let cornerAlpha = try XCTUnwrap(bitmap.colorAt(x: 0, y: 0)?.alphaComponent)
        XCTAssertEqual(cornerAlpha, 0, accuracy: 0.001)
        let preview = XCTAttachment(image: third)
        preview.name = "dynamic-app-icon-day-3"
        preview.lifetime = .keepAlways
        add(preview)
        let staticPreview = XCTAttachment(image: twelfth)
        staticPreview.name = "static-app-icon-day-12"
        staticPreview.lifetime = .keepAlways
        add(staticPreview)
        XCTAssertNil(DynamicAppIconRenderer.render(day: 0, baseImage: base))
        XCTAssertNil(DynamicAppIconRenderer.render(day: 32, baseImage: base))
    }
}
