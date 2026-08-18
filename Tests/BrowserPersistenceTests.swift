import XCTest
@testable import FireballWebKit

@MainActor
final class BrowserPersistenceTests: XCTestCase {
    func testPrivateObjectsNeverEnterPersistentSnapshot() async throws {
        let repository = CoreDataBrowserRepository(inMemory: true, cloudKitEnabled: false)
        var snapshot = try await repository.load()
        let privateProfile = BrowserProfile.privateProfile()
        let privateSpace = BrowserSpace(
            id: SpaceID(),
            profileID: privateProfile.id,
            name: "Private",
            sortIndex: 2,
            selectedTabID: nil,
            storageMode: .ephemeral,
            modifiedAt: .now
        )
        snapshot.profiles.append(privateProfile)
        snapshot.spaces.append(privateSpace)
        snapshot.tabs.append(
            BrowserTab(
                id: TabID(),
                spaceID: privateSpace.id,
                url: URL(string: "https://private.example"),
                title: "Private",
                sortIndex: 0,
                lastActiveAt: .now,
                storageMode: .ephemeral,
                modifiedAt: .now
            )
        )

        try repository.save(snapshot)
        let restored = try await repository.load()

        XCTAssertFalse(restored.profiles.contains { $0.storageMode == .ephemeral })
        XCTAssertFalse(restored.spaces.contains { $0.storageMode == .ephemeral })
        XCTAssertFalse(restored.tabs.contains { $0.storageMode == .ephemeral })
    }

    func testHistoryMovesBetweenLocalAndSyncedStoresWithoutDataLoss() async throws {
        let repository = CoreDataBrowserRepository(inMemory: true, cloudKitEnabled: false)
        var snapshot = try await repository.load()
        let visit = HistoryVisit(
            id: HistoryVisitID(),
            profileID: try XCTUnwrap(snapshot.profiles.first?.id),
            url: try XCTUnwrap(URL(string: "https://example.com")),
            title: "Example",
            visitedAt: .now,
            modifiedAt: .now
        )
        snapshot.history = [visit]
        try repository.save(snapshot)
        let localHistory = try await repository.load().history
        XCTAssertEqual(localHistory.map(\.id), [visit.id])

        snapshot.settings.historySyncEnabled = true
        snapshot.settings.modifiedAt = .now
        try repository.save(snapshot)

        let restored = try await repository.load()
        XCTAssertTrue(restored.settings.historySyncEnabled)
        XCTAssertEqual(restored.history.map(\.id), [visit.id])
    }

    func testHistoryOlderThanNinetyDaysIsNotRestored() async throws {
        let repository = CoreDataBrowserRepository(inMemory: true, cloudKitEnabled: false)
        var snapshot = try await repository.load()
        let oldDate = Date.now.addingTimeInterval(-91 * 24 * 60 * 60)
        snapshot.history = [
            HistoryVisit(
                id: HistoryVisitID(),
                profileID: try XCTUnwrap(snapshot.profiles.first?.id),
                url: try XCTUnwrap(URL(string: "https://old.example")),
                title: "Old",
                visitedAt: oldDate,
                modifiedAt: oldDate
            ),
        ]
        try repository.save(snapshot)

        let restoredHistory = try await repository.load().history
        XCTAssertTrue(restoredHistory.isEmpty)
    }

    func testOlderWriterCannotReplaceNewerProfileMetadata() async throws {
        let repository = CoreDataBrowserRepository(inMemory: true, cloudKitEnabled: false)
        var newer = try await repository.load()
        let baseline = Date.now
        newer.profiles[0].name = "Newer"
        newer.profiles[0].modifiedAt = baseline.addingTimeInterval(200)
        try repository.save(newer)

        var stale = newer
        stale.profiles[0].name = "Stale"
        stale.profiles[0].modifiedAt = baseline.addingTimeInterval(100)
        try repository.save(stale)

        let restored = try await repository.load()
        XCTAssertEqual(restored.profiles[0].name, "Newer")
    }

    func testTombstonePreventsOfflineBookmarkResurrection() async throws {
        let repository = CoreDataBrowserRepository(inMemory: true, cloudKitEnabled: false)
        var snapshot = try await repository.load()
        let bookmark = Bookmark(
            id: BookmarkID(),
            profileID: snapshot.profiles[0].id,
            url: URL(string: "https://deleted.example")!,
            title: "Deleted",
            createdAt: Date(timeIntervalSince1970: 100),
            modifiedAt: Date(timeIntervalSince1970: 100)
        )
        snapshot.bookmarks = [bookmark]
        try repository.save(snapshot)

        snapshot.bookmarks = []
        try repository.save(snapshot)
        snapshot.bookmarks = [bookmark]
        try repository.save(snapshot)

        let restored = try await repository.load()
        XCTAssertTrue(restored.bookmarks.isEmpty)
    }
}
