import XCTest
@testable import FireballWebKit

final class SessionRestorationTests: XCTestCase {
    func testPrivateTabsAreNeverRestored() throws {
        let spaceID = SpaceID()
        let regular = BrowserTab(
            id: TabID(),
            spaceID: spaceID,
            url: try XCTUnwrap(URL(string: "https://example.com")),
            title: "Example",
            sortIndex: 0,
            lastActiveAt: .now,
            storageMode: .persistent,
            modifiedAt: .now
        )
        let privateTab = BrowserTab(
            id: TabID(),
            spaceID: spaceID,
            url: try XCTUnwrap(URL(string: "https://private.example")),
            title: "Private",
            sortIndex: 1,
            lastActiveAt: .now,
            storageMode: .ephemeral,
            modifiedAt: .now
        )

        XCTAssertEqual(SessionRestoration().restorableTabs(from: [regular, privateTab]), [regular])
    }

    func testStableSortUsesUUIDWhenIndexesMatch() throws {
        let spaceID = SpaceID()
        let first = BrowserTab(
            id: TabID(rawValue: try XCTUnwrap(UUID(uuidString: "00000000-0000-4000-8000-000000000001"))),
            spaceID: spaceID,
            url: nil,
            title: "First",
            sortIndex: 0,
            lastActiveAt: .now,
            storageMode: .persistent,
            modifiedAt: .now
        )
        let second = BrowserTab(
            id: TabID(rawValue: try XCTUnwrap(UUID(uuidString: "00000000-0000-4000-8000-000000000002"))),
            spaceID: spaceID,
            url: nil,
            title: "Second",
            sortIndex: 0,
            lastActiveAt: .now,
            storageMode: .persistent,
            modifiedAt: .now
        )

        XCTAssertEqual(SessionRestoration().restorableTabs(from: [second, first]), [first, second])
    }
}
