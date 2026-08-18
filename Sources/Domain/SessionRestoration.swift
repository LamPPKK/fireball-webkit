import Foundation

struct SessionRestoration: Sendable {
    func restorableTabs(from tabs: [BrowserTab]) -> [BrowserTab] {
        tabs
            .filter { $0.storageMode == .persistent }
            .sorted { lhs, rhs in
                if lhs.sortIndex == rhs.sortIndex {
                    return lhs.id.rawValue.uuidString < rhs.id.rawValue.uuidString
                }
                return lhs.sortIndex < rhs.sortIndex
            }
    }
}
