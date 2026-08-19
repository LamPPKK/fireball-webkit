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

    func testClosingRegularWebTabArchivesAndRestoresIt() async throws {
        let repository = InMemoryBrowserRepository(snapshot: .initial())
        let store = makeStore(repository: repository)
        await store.bootstrap()
        let url = try XCTUnwrap(URL(string: "https://archive.example/article"))
        let closed = try XCTUnwrap(store.createTab(url: url))

        store.closeTab(closed.id)

        let archived = try XCTUnwrap(store.archivedTabs.first)
        XCTAssertEqual(archived.url, url)
        XCTAssertEqual(archived.profileID, store.activeProfile?.id)
        XCTAssertFalse(store.tabs.contains { $0.id == closed.id })

        let restored = try XCTUnwrap(store.restoreArchivedTab(archived.id))

        XCTAssertEqual(restored.url, url)
        XCTAssertEqual(store.selectedTabID, restored.id)
        XCTAssertTrue(store.archivedTabs.isEmpty)
        XCTAssertNotEqual(restored.id, closed.id)
        let persisted = try await repository.load()
        XCTAssertTrue(persisted.tabs.map(\.id).contains(restored.id))
    }

    func testPrivateAndHomeTabsNeverEnterArchive() async throws {
        let store = makeStore(repository: InMemoryBrowserRepository(snapshot: .initial()))
        await store.bootstrap()
        let homeID = try XCTUnwrap(store.activeTab?.id)
        store.closeTab(homeID)
        XCTAssertTrue(store.archivedTabs.isEmpty)

        let blank = try XCTUnwrap(store.createTab(url: URL(string: "about:blank")))
        store.closeTab(blank.id)
        XCTAssertTrue(store.archivedTabs.isEmpty)

        store.createPrivateSpace()
        let privateTab = try XCTUnwrap(
            store.createTab(url: URL(string: "https://private.example/secret"))
        )
        store.closeTab(privateTab.id)

        XCTAssertTrue(store.archivedTabs.isEmpty)
    }

    func testArchiveDropsEntriesOlderThanThirtyDays() async throws {
        var snapshot = BrowserSnapshot.initial()
        let profile = try XCTUnwrap(snapshot.profiles.first)
        let space = try XCTUnwrap(snapshot.spaces.first)
        let oldDate = Date.now.addingTimeInterval(-31 * 24 * 60 * 60)
        snapshot.archivedTabs = [
            ArchivedTab(
                id: ArchivedTabID(),
                profileID: profile.id,
                sourceSpaceID: space.id,
                url: try XCTUnwrap(URL(string: "https://expired.example")),
                title: "Expired",
                archivedAt: oldDate,
                modifiedAt: oldDate
            ),
        ]
        let store = makeStore(repository: InMemoryBrowserRepository(snapshot: snapshot))

        await store.bootstrap()

        XCTAssertTrue(store.archivedTabs.isEmpty)
    }

    func testArchiveKeepsOnlyTwoHundredNewestEntriesPerProfile() async throws {
        var snapshot = BrowserSnapshot.initial()
        let profile = try XCTUnwrap(snapshot.profiles.first)
        let space = try XCTUnwrap(snapshot.spaces.first)
        let now = Date.now
        snapshot.archivedTabs = try (0 ..< 205).map { index in
            ArchivedTab(
                id: ArchivedTabID(),
                profileID: profile.id,
                sourceSpaceID: space.id,
                url: try XCTUnwrap(URL(string: "https://archive.example/\(index)")),
                title: "Archive \(index)",
                archivedAt: now.addingTimeInterval(TimeInterval(-index)),
                modifiedAt: now.addingTimeInterval(TimeInterval(-index))
            )
        }
        let newestID = try XCTUnwrap(snapshot.archivedTabs.first?.id)
        let oldestIDs = Set(snapshot.archivedTabs.suffix(5).map(\.id))
        let store = makeStore(repository: InMemoryBrowserRepository(snapshot: snapshot))

        await store.bootstrap()

        XCTAssertEqual(store.archivedTabs.count, 200)
        XCTAssertTrue(store.archivedTabs.contains { $0.id == newestID })
        XCTAssertTrue(oldestIDs.isDisjoint(with: Set(store.archivedTabs.map(\.id))))
    }

    func testPinnedTabSortsFirstAndRestoresPinnedIntentFromArchive() async throws {
        let repository = InMemoryBrowserRepository(snapshot: .initial())
        let store = makeStore(repository: repository)
        await store.bootstrap()
        let first = try XCTUnwrap(store.createTab(url: URL(string: "https://first.example")))
        let pinned = try XCTUnwrap(store.createTab(url: URL(string: "https://pinned.example")))

        store.togglePinned(pinned.id)

        XCTAssertEqual(store.tabsInSelectedSpace.first?.id, pinned.id)
        XCTAssertTrue(store.tabs.first(where: { $0.id == pinned.id })?.isPinned == true)
        store.closeTab(pinned.id)
        let archived = try XCTUnwrap(store.archivedTabs.first(where: { $0.url == pinned.url }))
        XCTAssertNotNil(archived.pinnedAt)

        let restored = try XCTUnwrap(store.restoreArchivedTab(archived.id))

        XCTAssertTrue(restored.isPinned)
        XCTAssertEqual(store.tabsInSelectedSpace.first?.id, restored.id)
        XCTAssertTrue(store.tabs.contains { $0.id == first.id })
        let persisted = try await repository.load()
        XCTAssertTrue(persisted.tabs.contains { $0.id == restored.id && $0.isPinned })
    }

    func testAutomaticArchiveMovesOnlyStaleUnpinnedBackgroundTabs() async throws {
        let repository = InMemoryBrowserRepository(snapshot: .initial())
        let store = makeStore(repository: repository)
        await store.bootstrap()
        store.setAutomaticArchiveInterval(nil)
        let active = try XCTUnwrap(store.createTab(url: URL(string: "https://active.example")))
        let stale = try XCTUnwrap(store.createTab(url: URL(string: "https://stale.example"), activate: false))
        let pinned = try XCTUnwrap(store.createTab(url: URL(string: "https://pinned.example"), activate: false))
        store.togglePinned(pinned.id)
        let oldDate = Date.now.addingTimeInterval(-8 * 24 * 60 * 60)
        store.tabs[try XCTUnwrap(store.tabs.firstIndex(where: { $0.id == active.id }))].lastActiveAt = oldDate
        store.tabs[try XCTUnwrap(store.tabs.firstIndex(where: { $0.id == stale.id }))].lastActiveAt = oldDate
        store.tabs[try XCTUnwrap(store.tabs.firstIndex(where: { $0.id == pinned.id }))].lastActiveAt = oldDate

        store.setAutomaticArchiveInterval(.sevenDays)

        XCTAssertTrue(store.tabs.contains { $0.id == active.id })
        XCTAssertFalse(store.tabs.contains { $0.id == stale.id })
        XCTAssertTrue(store.tabs.contains { $0.id == pinned.id })
        XCTAssertEqual(store.archivedTabs.first(where: { $0.url == stale.url })?.sourceSpaceID, stale.spaceID)
        XCTAssertFalse(store.archivedTabs.contains { $0.url == active.url || $0.url == pinned.url })
    }

    func testAutomaticArchiveOffLeavesStaleTabOpen() async throws {
        let store = makeStore(repository: InMemoryBrowserRepository(snapshot: .initial()))
        await store.bootstrap()
        store.setAutomaticArchiveInterval(nil)
        let stale = try XCTUnwrap(store.createTab(url: URL(string: "https://stale.example"), activate: false))
        store.tabs[try XCTUnwrap(store.tabs.firstIndex(where: { $0.id == stale.id }))].lastActiveAt =
            Date.now.addingTimeInterval(-31 * 24 * 60 * 60)

        let archived = store.performAutomaticArchive()

        XCTAssertTrue(archived.isEmpty)
        XCTAssertTrue(store.tabs.contains { $0.id == stale.id })
        XCTAssertTrue(store.archivedTabs.isEmpty)
    }

    func testAutomaticArchiveRepairsSelectionInInactiveSpace() async throws {
        let store = makeStore(repository: InMemoryBrowserRepository(snapshot: .initial()))
        await store.bootstrap()
        store.setAutomaticArchiveInterval(nil)
        let mainSpaceID = try XCTUnwrap(store.selectedSpaceID)
        let profileID = try XCTUnwrap(store.activeProfile?.id)
        store.createSpace(name: "Research", profileID: profileID)
        let researchSpaceID = try XCTUnwrap(store.selectedSpaceID)
        let stale = try XCTUnwrap(store.createTab(url: URL(string: "https://stale.example")))
        await store.selectSpace(mainSpaceID)
        store.tabs[try XCTUnwrap(store.tabs.firstIndex(where: { $0.id == stale.id }))].lastActiveAt =
            Date.now.addingTimeInterval(-8 * 24 * 60 * 60)

        store.setAutomaticArchiveInterval(.sevenDays)

        XCTAssertFalse(store.tabs.contains { $0.id == stale.id })
        let repairedSelection = store.spaces.first(where: { $0.id == researchSpaceID })?.selectedTabID
        XCTAssertNotEqual(repairedSelection, stale.id)
        XCTAssertTrue(store.tabs.contains { $0.id == repairedSelection })
        XCTAssertEqual(store.selectedSpaceID, mainSpaceID)
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

    func testContentProcessTerminationUsesTheCorrectActiveAndBackgroundSessions() async throws {
        let store = makeStore(repository: InMemoryBrowserRepository(snapshot: .initial()))
        await store.bootstrap()
        let backgroundTab = try XCTUnwrap(store.createTab(url: URL(string: "https://background.example")))
        let backgroundSession = try XCTUnwrap(store.activeSession)
        let activeTab = try XCTUnwrap(store.createTab(url: URL(string: "https://active.example")))
        let activeSession = try XCTUnwrap(store.activeSession)

        XCTAssertFalse(backgroundSession === activeSession)
        XCTAssertNotNil(backgroundSession.webView.navigationDelegate)
        XCTAssertNotNil(activeSession.webView.navigationDelegate)

        backgroundSession.webContentProcessDidTerminate()
        XCTAssertFalse(store.isSessionLoaded(for: backgroundTab.id))
        XCTAssertTrue(store.isSessionLoaded(for: activeTab.id))

        activeSession.webContentProcessDidTerminate()
        XCTAssertTrue(store.isSessionLoaded(for: activeTab.id))
        XCTAssertNil(store.errorMessage)

        activeSession.webContentProcessDidTerminate()
        XCTAssertEqual(store.errorMessage, "The page stopped unexpectedly. Reload it when you are ready.")
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
