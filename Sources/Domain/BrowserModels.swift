import Foundation

struct ProfileID: RawRepresentable, Hashable, Codable, Sendable {
    let rawValue: String
}

struct SpaceID: RawRepresentable, Hashable, Codable, Sendable {
    let rawValue: String
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

enum ExtensionSource: String, Codable, Sendable {
    case contentRuleList = "content_rule_list"
}

enum PrivateAccessPolicy: String, Codable, Sendable {
    case unlocked
    case biometric
    case deviceOwner = "device_owner"
}

struct BrowserProfile: Hashable, Codable, Sendable {
    let id: ProfileID
    let storageMode: StorageMode
}

struct RestorableTab: Hashable, Codable, Sendable {
    let url: URL
    let profile: BrowserProfile
}
