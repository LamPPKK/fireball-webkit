import Foundation

protocol UUIDBackedIdentifier: RawRepresentable, Hashable, Codable, Sendable where RawValue == UUID {
    init(rawValue: UUID)
}

extension UUIDBackedIdentifier {
    init() {
        self.init(rawValue: UUID())
    }
}

struct ProfileID: UUIDBackedIdentifier {
    let rawValue: UUID
}

struct SpaceID: UUIDBackedIdentifier {
    let rawValue: UUID
}

struct TabID: UUIDBackedIdentifier {
    let rawValue: UUID
}

struct ArchivedTabID: UUIDBackedIdentifier {
    let rawValue: UUID
}

struct BookmarkID: UUIDBackedIdentifier {
    let rawValue: UUID
}

struct HistoryVisitID: UUIDBackedIdentifier {
    let rawValue: UUID
}

struct DownloadID: UUIDBackedIdentifier {
    let rawValue: UUID
}

enum StorageMode: String, Codable, Sendable {
    case persistent
    case ephemeral
}

enum TabLayout: String, CaseIterable, Codable, Sendable {
    case classic
    case floating
    case verticalSidebar = "vertical_sidebar"
    case grid
}

enum SearchProvider: String, CaseIterable, Codable, Sendable {
    case brave
    case duckDuckGo = "duckduckgo"
    case google
    case bing

    var displayName: String {
        switch self {
        case .brave: "Brave Search"
        case .duckDuckGo: "DuckDuckGo"
        case .google: "Google"
        case .bing: "Bing"
        }
    }

    func searchURL(for query: String) -> URL? {
        let baseURL: String
        switch self {
        case .brave: baseURL = "https://search.brave.com/search"
        case .duckDuckGo: baseURL = "https://duckduckgo.com/"
        case .google: baseURL = "https://www.google.com/search"
        case .bing: baseURL = "https://www.bing.com/search"
        }
        var components = URLComponents(string: baseURL)
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        return components?.url
    }
}

enum ExtensionSource: String, Codable, Sendable {
    case contentRuleList = "content_rule_list"
}

enum PrivateAccessPolicy: String, Codable, Sendable {
    case unlocked
    case biometric
    case deviceOwner = "device_owner"
}

struct BrowserProfile: Identifiable, Hashable, Codable, Sendable {
    static let defaultID = ProfileID(rawValue: UUID(uuidString: "F1AEB000-0000-4000-8000-000000000001")!)

    let id: ProfileID
    var name: String
    var colorHex: String
    let storageMode: StorageMode
    var searchProvider: SearchProvider
    var blockerEnabled: Bool
    var modifiedAt: Date

    static func regularDefault(now: Date = .now) -> BrowserProfile {
        BrowserProfile(
            id: defaultID,
            name: "Default",
            colorHex: "67F58A",
            storageMode: .persistent,
            searchProvider: .brave,
            blockerEnabled: true,
            modifiedAt: now
        )
    }

    static func privateProfile(now: Date = .now) -> BrowserProfile {
        BrowserProfile(
            id: ProfileID(),
            name: "Private",
            colorHex: "F59E66",
            storageMode: .ephemeral,
            searchProvider: .brave,
            blockerEnabled: true,
            modifiedAt: now
        )
    }
}

struct BrowserSpace: Identifiable, Hashable, Codable, Sendable {
    let id: SpaceID
    let profileID: ProfileID
    var name: String
    var sortIndex: Double
    var selectedTabID: TabID?
    let storageMode: StorageMode
    var modifiedAt: Date
}

struct BrowserTab: Identifiable, Hashable, Codable, Sendable {
    let id: TabID
    let spaceID: SpaceID
    var url: URL?
    var title: String
    var sortIndex: Double
    var lastActiveAt: Date
    let storageMode: StorageMode
    var modifiedAt: Date

    var isPrivate: Bool { storageMode == .ephemeral }
}

struct ArchivedTab: Identifiable, Hashable, Codable, Sendable {
    let id: ArchivedTabID
    let profileID: ProfileID
    let sourceSpaceID: SpaceID
    let url: URL
    var title: String
    let archivedAt: Date
    var modifiedAt: Date
}

struct Bookmark: Identifiable, Hashable, Codable, Sendable {
    let id: BookmarkID
    let profileID: ProfileID
    var url: URL
    var title: String
    var createdAt: Date
    var modifiedAt: Date
}

struct HistoryVisit: Identifiable, Hashable, Codable, Sendable {
    let id: HistoryVisitID
    let profileID: ProfileID
    var url: URL
    var title: String
    var visitedAt: Date
    var modifiedAt: Date
}

struct BrowserSettings: Hashable, Codable, Sendable {
    var historySyncEnabled = false
    var lastSelectedSpaceID: SpaceID?
    var modifiedAt = Date.now
}

struct BrowserSnapshot: Hashable, Codable, Sendable {
    var profiles: [BrowserProfile]
    var spaces: [BrowserSpace]
    var tabs: [BrowserTab]
    var archivedTabs: [ArchivedTab]
    var bookmarks: [Bookmark]
    var history: [HistoryVisit]
    var settings: BrowserSettings

    static func initial(now: Date = .now) -> BrowserSnapshot {
        let profile = BrowserProfile.regularDefault(now: now)
        let space = BrowserSpace(
            id: SpaceID(),
            profileID: profile.id,
            name: "Main",
            sortIndex: 0,
            selectedTabID: nil,
            storageMode: .persistent,
            modifiedAt: now
        )
        return BrowserSnapshot(
            profiles: [profile],
            spaces: [space],
            tabs: [],
            archivedTabs: [],
            bookmarks: [],
            history: [],
            settings: BrowserSettings(modifiedAt: now)
        )
    }
}
