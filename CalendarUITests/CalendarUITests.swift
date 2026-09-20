import XCTest

final class CalendarUITests: XCTestCase {
    func testUpdateFrequencyOffersNeverDailyAndWeekly() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--fixed-today", "2026-09-19", "--show-settings"]
        app.launch()

        let settings = app.windows["设置"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        let frequency = settings.descendants(matching: .any)["updateFrequencyPicker"]
        XCTAssertTrue(frequency.waitForExistence(timeout: 3))
        frequency.click()
        XCTAssertTrue(app.menuItems["从不"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.menuItems["每天"].exists)
        XCTAssertTrue(app.menuItems["每周"].exists)
        XCTAssertFalse(app.menuItems["每小时"].exists)
        XCTAssertFalse(app.menuItems["每 6 小时"].exists)
    }

    func testMonthPickerKeepsTwoDigitMonthsOnOneLineAndMenuHasYearPicker() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--fixed-today", "2026-09-19"]
        app.launch()

        let main = app.windows["万年历"]
        XCTAssertTrue(main.waitForExistence(timeout: 10))
        main.buttons["monthPicker"].click()
        XCTAssertTrue(app.buttons["monthOption-10"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["monthOption-12"].exists)
        captureScreen("month-picker-two-digit-months")
        app.buttons["monthOption-10"].click()
        XCTAssertTrue(main.buttons["day-2026-10-19"].waitForExistence(timeout: 3))

        app.menuBars.menuBarItems["日历"].click()
        app.menuItems["显示菜单栏日历"].click()
        XCTAssertTrue(app.buttons["menuYearPicker"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["menuMonthPicker"].exists)
        app.buttons["menuYearPicker"].click()
        XCTAssertTrue(app.buttons["yearOption-2026"].waitForExistence(timeout: 3))
        captureScreen("menu-year-picker")
    }

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
    private func captureScreen(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }
}
