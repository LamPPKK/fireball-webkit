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

    func testRepositorySyncStatusChangesReachBrowserStore() async {
        let repository = InMemoryBrowserRepository(snapshot: .initial())
        let store = makeStore(repository: repository)
        await store.bootstrap()

        repository.updateSyncStatus(.syncing)

        XCTAssertEqual(store.syncStatus, .syncing)
    }

    func testLastSelectedRegularSpaceRestoresAfterRelaunch() async throws {
        var snapshot = BrowserSnapshot.initial()
        let secondSpace = BrowserSpace(
            id: SpaceID(),
            profileID: try XCTUnwrap(snapshot.profiles.first?.id),
            name: "Research",
            sortIndex: 1,
            selectedTabID: nil,
            storageMode: .persistent,
            modifiedAt: .now
        )
        snapshot.spaces.append(secondSpace)
        snapshot.settings.lastSelectedSpaceID = secondSpace.id
        let store = makeStore(repository: InMemoryBrowserRepository(snapshot: snapshot))

        await store.bootstrap()

        XCTAssertEqual(store.selectedSpaceID, secondSpace.id)
        XCTAssertEqual(store.activeTab?.spaceID, secondSpace.id)
    }

    func testLRUTrimmingNeverReleasesActiveSession() async throws {
        let store = makeStore(repository: InMemoryBrowserRepository(snapshot: .initial()))
        await store.bootstrap()
        let old = try XCTUnwrap(store.createTab(url: URL(string: "https://old.example")))
        let recent = try XCTUnwrap(store.createTab(url: URL(string: "https://recent.example")))
        let active = try XCTUnwrap(store.createTab(url: URL(string: "https://active.example")))
        store.tabs[store.tabs.firstIndex(where: { $0.id == old.id })!].lastActiveAt = Date(timeIntervalSince1970: 1)
        store.tabs[store.tabs.firstIndex(where: { $0.id == recent.id })!].lastActiveAt = Date(timeIntervalSince1970: 2)

        let evicted = store.trimBackgroundSessions(keepingMostRecent: 1)

        XCTAssertTrue(evicted.contains(old.id))
        XCTAssertFalse(evicted.contains(recent.id))
        XCTAssertFalse(evicted.contains(active.id))
        XCTAssertFalse(store.isSessionLoaded(for: old.id))
        XCTAssertTrue(store.isSessionLoaded(for: recent.id))
        XCTAssertTrue(store.isSessionLoaded(for: active.id))
    }

    func testBlockerChangeIsStagedWithoutReloadingActiveWebView() async throws {
        let store = makeStore(repository: InMemoryBrowserRepository(snapshot: .initial()))
        await store.bootstrap()
        _ = store.createTab(url: URL(string: "https://form.example"))
        let originalSession = try XCTUnwrap(store.activeSession)
        let profileID = try XCTUnwrap(store.activeProfile?.id)

        store.setBlockerEnabled(false, for: profileID)

        XCTAssertTrue(originalSession === store.activeSession)
        XCTAssertTrue(originalSession.hasPendingPolicyChange)
        XCTAssertFalse(originalSession.profile.blockerEnabled)
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

    func testCancelledProfileUnlockFailsClosed() async throws {
        let snapshot = BrowserSnapshot.initial()
        let profileID = try XCTUnwrap(snapshot.profiles.first?.id)
        let locks = FakeProfileLockStore(unlockResult: .failure(CancellationError()))
        try locks.enable(for: profileID)
        let store = makeStore(repository: InMemoryBrowserRepository(snapshot: snapshot), profileLocks: locks)
        await store.bootstrap()

        await store.unlockActiveProfileIfNeeded()

        XCTAssertTrue(store.selectedProfileIsLocked)
        XCTAssertEqual(store.errorMessage, "Profile remains locked.")
    }

    func testDeviceOwnerRecoveryUnlocksProfileAfterBiometricFailure() async throws {
        let snapshot = BrowserSnapshot.initial()
        let profileID = try XCTUnwrap(snapshot.profiles.first?.id)
        let locks = FakeProfileLockStore(unlockResult: .failure(SecureAccessError.authenticationFailed))
        try locks.enable(for: profileID)
        let store = makeStore(repository: InMemoryBrowserRepository(snapshot: snapshot), profileLocks: locks)
        await store.bootstrap()

        await store.recoverActiveProfileAccess()

        XCTAssertFalse(store.selectedProfileIsLocked)
    }

    private func makeStore(
        repository: InMemoryBrowserRepository,
        profileLocks: FakeProfileLockStore = FakeProfileLockStore()
    ) -> BrowserStore {
        BrowserStore(
            repository: repository,
            profileLocks: profileLocks,
            ownerAuthenticator: FakeOwnerAuthenticator(result: .success(())),
            loadBundledRules: false
        )
    }
}

@MainActor
private final class FakeProfileLockStore: ProfileLocking {
    private var enabled: Set<ProfileID> = []
    private let unlockResult: Result<Void, any Error>

    init(unlockResult: Result<Void, any Error> = .success(())) {
        self.unlockResult = unlockResult
    }

    func isEnabled(for profileID: ProfileID) -> Bool { enabled.contains(profileID) }
    func enable(for profileID: ProfileID) throws { enabled.insert(profileID) }
    func disable(for profileID: ProfileID) throws { enabled.remove(profileID) }
    func unlock(profileID: ProfileID, reason: String) async throws {
        _ = profileID
        _ = reason
        try unlockResult.get()
    }
}
