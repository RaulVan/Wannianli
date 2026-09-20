import XCTest
@testable import Wannianli

final class HorizontalMonthSwipeRecognizerTests: XCTestCase {
    func testTwoFingerSwipeLeftMovesToPreviousMonth() {
        var recognizer = HorizontalMonthSwipeRecognizer(threshold: 45)
        recognizer.begin()

        XCTAssertNil(recognizer.update(deltaX: -20, deltaY: 2))
        XCTAssertEqual(recognizer.update(deltaX: -26, deltaY: 3), -1)
        XCTAssertNil(recognizer.update(deltaX: -60, deltaY: 0), "同一次手势只能切换一次")
    }

    func testTwoFingerSwipeRightAdvancesOneMonth() {
        var recognizer = HorizontalMonthSwipeRecognizer(threshold: 45)
        recognizer.begin()

        XCTAssertEqual(recognizer.update(deltaX: 48, deltaY: 4), 1)
    }

    func testVerticalScrollDoesNotChangeMonth() {
        var recognizer = HorizontalMonthSwipeRecognizer(threshold: 45)
        recognizer.begin()

        XCTAssertNil(recognizer.update(deltaX: 20, deltaY: 35))
        XCTAssertEqual(recognizer.accumulatedX, 0)
    }

    func testNewGestureCanChangeMonthAgain() {
        var recognizer = HorizontalMonthSwipeRecognizer(threshold: 45)
        recognizer.begin()
        XCTAssertEqual(recognizer.update(deltaX: -50, deltaY: 0), -1)

        recognizer.end()
        recognizer.begin()
        XCTAssertEqual(recognizer.update(deltaX: 50, deltaY: 0), 1)
    }
}
