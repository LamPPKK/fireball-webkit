import XCTest
@testable import FireballWebKit

@MainActor
final class BrowserStoreTests: XCTestCase {
    func testBootstrapCreatesRestorableHomeTab() async throws {
        let repository = InMemoryBrowserRepository(snapshot: .initial())
        let store = makeStore(repository: repository)

        await store.bootstrap()

        XCTAssertTrue(store.isReady)
        XCTAssertEqual(store.tabs.count, 1)
        XCTAssertEqual(store.activeTab?.storageMode, .persistent)
        XCTAssertNil(store.activeTab?.url)
    }

    func testPrivateSpaceIsMemoryOnly() async throws {
        let repository = InMemoryBrowserRepository(snapshot: .initial())
        let store = makeStore(repository: repository)
        await store.bootstrap()

        store.createPrivateSpace()
        XCTAssertEqual(store.selectedSpace?.storageMode, .ephemeral)

        let persisted = try await repository.load()
        XCTAssertFalse(persisted.spaces.contains { $0.storageMode == .ephemeral })
        XCTAssertFalse(persisted.tabs.contains { $0.storageMode == .ephemeral })
    }

    func testHistorySyncDefaultsOff() async {
        let store = makeStore(repository: InMemoryBrowserRepository(snapshot: .initial()))
        await store.bootstrap()

        XCTAssertFalse(store.settings.historySyncEnabled)
        store.setHistorySyncEnabled(true)
        XCTAssertTrue(store.settings.historySyncEnabled)
    }

    func testPrivateSpaceLocksAcrossBackgroundTransition() async {
        let store = makeStore(repository: InMemoryBrowserRepository(snapshot: .initial()))
        await store.bootstrap()
        store.createPrivateSpace()

        store.lockProtectedContent()
        XCTAssertTrue(store.selectedProfileIsLocked)

        await store.revealAfterForeground()
        XCTAssertFalse(store.selectedProfileIsLocked)
    }

    private func makeStore(repository: InMemoryBrowserRepository) -> BrowserStore {
        BrowserStore(
            repository: repository,
            profileLocks: FakeProfileLockStore(),
            ownerAuthenticator: FakeOwnerAuthenticator(result: .success(())),
            loadBundledRules: false
        )
    }
}

@MainActor
private final class FakeProfileLockStore: ProfileLocking {
    private var enabled: Set<ProfileID> = []

    func isEnabled(for profileID: ProfileID) -> Bool { enabled.contains(profileID) }
    func enable(for profileID: ProfileID) throws { enabled.insert(profileID) }
    func disable(for profileID: ProfileID) throws { enabled.remove(profileID) }
    func unlock(profileID: ProfileID, reason: String) async throws {
        _ = profileID
        _ = reason
    }
}
