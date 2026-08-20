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

struct BlockerSiteExceptionID: UUIDBackedIdentifier {
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

enum AutomaticArchiveInterval: Int, CaseIterable, Codable, Sendable {
    case oneDay = 1
    case sevenDays = 7
    case thirtyDays = 30

    var displayName: String {
        switch self {
        case .oneDay: "After 1 day"
        case .sevenDays: "After 7 days"
        case .thirtyDays: "After 30 days"
        }
    }

    var timeInterval: TimeInterval {
        TimeInterval(rawValue) * 24 * 60 * 60
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
    var pinnedAt: Date? = nil
    let storageMode: StorageMode
    var modifiedAt: Date

    var isPrivate: Bool { storageMode == .ephemeral }
    var isPinned: Bool { pinnedAt != nil }
}

struct ArchivedTab: Identifiable, Hashable, Codable, Sendable {
    let id: ArchivedTabID
    let profileID: ProfileID
    let sourceSpaceID: SpaceID
    let url: URL
    var title: String
    let archivedAt: Date
    var pinnedAt: Date? = nil
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

struct BlockerSiteException: Identifiable, Hashable, Codable, Sendable {
    let id: BlockerSiteExceptionID
    let profileID: ProfileID
    let host: String
    let createdAt: Date
    var modifiedAt: Date
}

enum BlockerSitePolicy {
    static func normalizedHost(for url: URL?) -> String? {
        guard let url,
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host() else { return nil }
        return normalizedHost(host)
    }

    static func normalizedHost(_ rawHost: String) -> String? {
        var host = rawHost.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if host.hasPrefix("["), host.hasSuffix("]") {
            host.removeFirst()
            host.removeLast()
        }
        while host.hasSuffix(".") {
            host.removeLast()
        }
        guard !host.isEmpty, host.utf8.count <= 253,
              host.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              host.rangeOfCharacter(from: CharacterSet(charactersIn: "/\\?#@")) == nil else {
            return nil
        }
        let candidate = host.contains(":") ? "https://[\(host)]" : "https://\(host)"
        guard var canonical = URLComponents(string: candidate)?.host?.lowercased(),
              !canonical.isEmpty else { return nil }
        if canonical.hasPrefix("["), canonical.hasSuffix("]") {
            canonical.removeFirst()
            canonical.removeLast()
        }
        return canonical
    }

    static func rulesEnabled(
        profileEnabled: Bool,
        for url: URL?,
        allowlistedHosts: Set<String>
    ) -> Bool {
        guard profileEnabled else { return false }
        guard let host = normalizedHost(for: url) else { return true }
        return !allowlistedHosts.contains(host)
    }
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
    var automaticArchiveInterval: AutomaticArchiveInterval? = .sevenDays
    var modifiedAt = Date.now
}

struct BrowserSnapshot: Hashable, Codable, Sendable {
    var profiles: [BrowserProfile]
    var spaces: [BrowserSpace]
    var tabs: [BrowserTab]
    var archivedTabs: [ArchivedTab]
    var blockerSiteExceptions: [BlockerSiteException]
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
            blockerSiteExceptions: [],
            bookmarks: [],
            history: [],
            settings: BrowserSettings(modifiedAt: now)
        )
    }
}

extension BrowserSnapshot {
    private enum CodingKeys: String, CodingKey {
        case profiles
        case spaces
        case tabs
        case archivedTabs
        case blockerSiteExceptions
        case bookmarks
        case history
        case settings
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profiles = try container.decode([BrowserProfile].self, forKey: .profiles)
        spaces = try container.decode([BrowserSpace].self, forKey: .spaces)
        tabs = try container.decode([BrowserTab].self, forKey: .tabs)
        archivedTabs = try container.decode([ArchivedTab].self, forKey: .archivedTabs)
        blockerSiteExceptions = try container.decodeIfPresent(
            [BlockerSiteException].self,
            forKey: .blockerSiteExceptions
        ) ?? []
        bookmarks = try container.decode([Bookmark].self, forKey: .bookmarks)
        history = try container.decode([HistoryVisit].self, forKey: .history)
        settings = try container.decode(BrowserSettings.self, forKey: .settings)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(profiles, forKey: .profiles)
        try container.encode(spaces, forKey: .spaces)
        try container.encode(tabs, forKey: .tabs)
        try container.encode(archivedTabs, forKey: .archivedTabs)
        try container.encode(blockerSiteExceptions, forKey: .blockerSiteExceptions)
        try container.encode(bookmarks, forKey: .bookmarks)
        try container.encode(history, forKey: .history)
        try container.encode(settings, forKey: .settings)
    }
}
