import WebKit

@MainActor
final class WebsiteDataStoreRegistry {
    private var ephemeralStores: [ProfileID: WKWebsiteDataStore] = [:]

    func store(for profile: BrowserProfile) -> WKWebsiteDataStore {
        switch profile.storageMode {
        case .persistent:
            return WKWebsiteDataStore(forIdentifier: profile.id.rawValue)
        case .ephemeral:
            if let existing = ephemeralStores[profile.id] {
                return existing
            }
            let store = WKWebsiteDataStore.nonPersistent()
            ephemeralStores[profile.id] = store
            return store
        }
    }

    func removeEphemeralStore(for profileID: ProfileID) {
        ephemeralStores.removeValue(forKey: profileID)
    }

    func removePersistentStore(for profileID: ProfileID) async throws {
        try await WKWebsiteDataStore.remove(forIdentifier: profileID.rawValue)
    }
}
