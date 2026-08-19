import Foundation

struct SessionRestoration: Sendable {
    func restorableTabs(from tabs: [BrowserTab]) -> [BrowserTab] {
        tabs
            .filter { $0.storageMode == .persistent }
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned {
                    return lhs.isPinned
                }
                if let lhsPinned = lhs.pinnedAt, let rhsPinned = rhs.pinnedAt, lhsPinned != rhsPinned {
                    return lhsPinned < rhsPinned
                }
                if lhs.sortIndex == rhs.sortIndex {
                    return lhs.id.rawValue.uuidString < rhs.id.rawValue.uuidString
                }
                return lhs.sortIndex < rhs.sortIndex
            }
    }
}
