import XCTest
import UIKit

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

    @MainActor
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

    @MainActor
    func testBrowserChromePassesAccessibilityAudit() throws {
        let app = XCUIApplication()
        app.launchEnvironment["FIREBALL_UI_TESTING"] = "1"
        app.launch()

        XCTAssertTrue(app.textFields["browser.omnibox"].waitForExistence(timeout: 10))
        try app.performAccessibilityAudit(
            for: [.sufficientElementDescription, .hitRegion, .dynamicType, .textClipped, .trait]
        )
    }

    @MainActor
    func testTabGridPassesAccessibilityAudit() throws {
        let app = launchApp()
        app.buttons["browser.tabs"].tap()

        XCTAssertTrue(app.buttons["tabs.new"].waitForExistence(timeout: 3))
        try performAccessibilityAudit(app)
    }

    @MainActor
    func testLibraryPassesAccessibilityAudit() throws {
        let app = launchApp()
        app.buttons["browser.library"].tap()

        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 3))
        try performAccessibilityAudit(app)
    }

    @MainActor
    func testSettingsPassesAccessibilityAudit() throws {
        let app = launchApp()
        app.buttons["browser.settings"].tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        try performAccessibilityAudit(app)
    }

    @MainActor
    func testIPadHardwareKeyboardCreatesTabAndFocusesAddressBar() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("Hardware-keyboard commands are exercised on the iPad destination.")
        }

        let app = XCUIApplication()
        app.launchEnvironment["FIREBALL_UI_TESTING"] = "1"
        app.launch()

        let omnibox = app.textFields["browser.omnibox"]
        XCTAssertTrue(omnibox.waitForExistence(timeout: 10))
        let status = app.descendants(matching: .any)["browser.status"]
        XCTAssertTrue(status.exists)
        let initialTabCount = try XCTUnwrap(tabCount(from: status.value as? String))

        app.typeKey("l", modifierFlags: .command)
        app.typeText("example.com")
        XCTAssertEqual(omnibox.value as? String, "example.com")

        app.typeKey("t", modifierFlags: .command)
        XCTAssertEqual(tabCount(from: status.value as? String), initialTabCount + 1)
    }

    private func tabCount(from status: String?) -> Int? {
        guard let status,
              let match = status.range(of: #"[0-9]+ tab"#, options: .regularExpression) else {
            return nil
        }
        return Int(status[match].split(separator: " ")[0])
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["FIREBALL_UI_TESTING"] = "1"
        app.launch()
        XCTAssertTrue(app.textFields["browser.omnibox"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor
    private func performAccessibilityAudit(_ app: XCUIApplication) throws {
        try app.performAccessibilityAudit(
            for: [.sufficientElementDescription, .hitRegion, .dynamicType, .textClipped, .trait]
        )
    }
}
