import XCTest

final class BrowserSmokeUITests: XCTestCase {
    @MainActor
    func testHomeTabGridAndSettingsAreReachable() throws {
        let app = XCUIApplication()
        app.launchEnvironment["FIREBALL_UI_TESTING"] = "1"
        app.launch()

        XCTAssertTrue(app.textFields["browser.omnibox"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollViews["browser.home"].exists)

        app.buttons["browser.tabs"].tap()
        XCTAssertTrue(app.buttons["tabs.new"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()

        app.buttons["browser.settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
    }

    func testTabCardSwipeClosesOneOfTwoTabs() {
        let app = XCUIApplication()
        app.launchEnvironment["FIREBALL_UI_TESTING"] = "1"
        app.launch()

        let tabsButton = app.buttons["browser.tabs"]
        XCTAssertTrue(tabsButton.waitForExistence(timeout: 10))
        tabsButton.tap()
        XCTAssertTrue(app.buttons["tabs.new"].waitForExistence(timeout: 3))
        app.buttons["tabs.new"].tap()

        tabsButton.tap()
        let cards = app.buttons.matching(identifier: "tab.card")
        XCTAssertEqual(cards.count, 2)
        cards.element(boundBy: 0).swipeLeft()

        XCTAssertEqual(cards.count, 1)
    }
}
