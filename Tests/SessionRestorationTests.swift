import XCTest
@testable import FireballWebKit

final class SessionRestorationTests: XCTestCase {
    func testPrivateTabsAreNeverRestored() throws {
        let regular = RestorableTab(
            url: try XCTUnwrap(URL(string: "https://example.com")),
            profile: BrowserProfile(id: ProfileID(rawValue: "regular"), storageMode: .persistent)
        )
        let privateTab = RestorableTab(
            url: try XCTUnwrap(URL(string: "https://private.example")),
            profile: BrowserProfile(id: ProfileID(rawValue: "private"), storageMode: .ephemeral)
        )

        XCTAssertEqual(SessionRestoration().restorableTabs(from: [regular, privateTab]), [regular])
    }
}
