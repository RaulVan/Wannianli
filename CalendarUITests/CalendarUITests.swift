import XCTest

final class CalendarUITests: XCTestCase {
    func testCalendarJourney() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--fixed-today", "2026-09-19"]
        app.launch()
        let main = app.windows["万年历"]
        XCTAssertTrue(main.waitForExistence(timeout: 10))
        capture(main, "main-light")
        app.buttons["day-2026-09-25"].firstMatch.click()
        XCTAssertTrue(app.staticTexts["八月十五"].firstMatch.waitForExistence(timeout: 3))
        app.buttons["下个月"].firstMatch.click()
        XCTAssertTrue(app.buttons["day-2026-10-25"].firstMatch.exists)
        app.buttons["todayButton"].firstMatch.click()
        XCTAssertTrue(app.staticTexts["八月初九"].firstMatch.exists)
        app.typeKey("m", modifierFlags: [.command, .shift])
        XCTAssertTrue(app.buttons["openFullCalendar"].waitForExistence(timeout: 5))
        capture(app, "menu-light")
        app.buttons["openFullCalendar"].click()
        app.buttons["设置"].firstMatch.click()
        XCTAssertTrue(app.windows["设置"].waitForExistence(timeout: 3))
        capture(app.windows["设置"], "settings")
        app.windows["设置"].buttons[XCUIIdentifierCloseWindow].click()
        main.buttons[XCUIIdentifierCloseWindow].click()
        XCTAssertTrue(app.state == .runningForeground || app.state == .runningBackground)
        app.typeKey("0", modifierFlags: [.command])
        XCTAssertTrue(main.waitForExistence(timeout: 3))
        capture(main, "main-reopened")
    }
    private func capture(_ element: XCUIElement, _ name: String) {
        let attachment = XCTAttachment(screenshot: element.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }
}
