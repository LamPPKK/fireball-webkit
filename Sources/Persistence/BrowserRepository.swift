import Foundation

enum BrowserSyncStatus: Equatable, Sendable {
    case starting
    case localOnly
    case available
    case degraded(String)

    var label: String {
        switch self {
        case .starting: "SYNC STARTING"
        case .localOnly: "LOCAL ONLY"
        case .available: "ICLOUD READY"
        case .degraded: "SYNC DEGRADED"
        }
    }
}

@MainActor
protocol BrowserRepository: AnyObject {
    var syncStatus: BrowserSyncStatus { get }
    var onExternalChange: (@MainActor @Sendable () -> Void)? { get set }
    func load() async throws -> BrowserSnapshot
    func save(_ snapshot: BrowserSnapshot) throws
}

@MainActor
final class InMemoryBrowserRepository: BrowserRepository {
    private var snapshot: BrowserSnapshot
    let syncStatus: BrowserSyncStatus
    var onExternalChange: (@MainActor @Sendable () -> Void)?

    init(snapshot: BrowserSnapshot = .initial(), syncStatus: BrowserSyncStatus = .localOnly) {
        self.snapshot = snapshot
        self.syncStatus = syncStatus
    }

    func load() async throws -> BrowserSnapshot {
        snapshot
    }

    func save(_ snapshot: BrowserSnapshot) throws {
        self.snapshot = snapshot
    }
}
