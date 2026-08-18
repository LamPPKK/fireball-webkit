import Foundation

struct SessionRestoration: Sendable {
    func restorableTabs(from tabs: [RestorableTab]) -> [RestorableTab] {
        tabs.filter { $0.profile.storageMode == .persistent }
    }
}
