import XCTest
@testable import FireballWebKit

final class BrowserModelsTests: XCTestCase {
    func testDefaultProfileUsesStableUUIDAndBraveSearch() {
        let first = BrowserProfile.regularDefault()
        let second = BrowserProfile.regularDefault()

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(first.searchProvider, .brave)
        XCTAssertEqual(first.storageMode, .persistent)
    }

    func testSpacesAndProfilesRemainSeparateConcepts() {
        let profile = BrowserProfile.regularDefault()
        let first = BrowserSpace(
            id: SpaceID(),
            profileID: profile.id,
            name: "Work",
            sortIndex: 0,
            selectedTabID: nil,
            storageMode: .persistent,
            modifiedAt: .now
        )
        let second = BrowserSpace(
            id: SpaceID(),
            profileID: profile.id,
            name: "Research",
            sortIndex: 1,
            selectedTabID: nil,
            storageMode: .persistent,
            modifiedAt: .now
        )

        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(first.profileID, second.profileID)
    }
}
