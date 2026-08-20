import CloudKit
import CoreData
import Foundation

@MainActor
final class CoreDataBrowserRepository: BrowserRepository {
    static let cloudContainerIdentifier = "iCloud.com.fireball.browser"

    private enum Configuration {
        static let cloud = "Cloud"
        static let local = "Local"
    }

    private enum Entity {
        static let synced = "SyncedRecord"
        static let local = "LocalRecord"
    }

    private enum RecordKind: String, CaseIterable {
        case profile
        case space
        case tab
        case archivedTab = "archived_tab"
        case blockerSiteException = "blocker_site_exception"
        case bookmark
        case history
        case settings
    }

    private static let tombstoneLifetime: TimeInterval = 30 * 24 * 60 * 60
    private static let settingsRecordID = "settings"

    private let container: NSPersistentCloudKitContainer
    private let cloudKitEnabled: Bool
    private let accountContainer: CKContainer?
    private var didLoadStores = false
    private var remoteChangeObserver: NotificationObserverToken?
    private var cloudEventObserver: NotificationObserverToken?
    private var accountChangeObserver: NotificationObserverToken?

    private(set) var syncStatus: BrowserSyncStatus = .starting
    var onExternalChange: (@MainActor @Sendable () -> Void)?
    var onSyncStatusChange: (@MainActor @Sendable (BrowserSyncStatus) -> Void)?

    init(inMemory: Bool = false, cloudKitEnabled: Bool = true) {
        self.cloudKitEnabled = cloudKitEnabled && !inMemory
        accountContainer = self.cloudKitEnabled
            ? CKContainer(identifier: Self.cloudContainerIdentifier)
            : nil
        container = NSPersistentCloudKitContainer(
            name: "FireballBrowser",
            managedObjectModel: Self.makeManagedObjectModel()
        )
        container.persistentStoreDescriptions = Self.makeStoreDescriptions(
            inMemory: inMemory,
            cloudKitEnabled: self.cloudKitEnabled
        )
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
    }

    func load() async throws -> BrowserSnapshot {
        if !didLoadStores {
            try await loadStores()
        }
        let snapshot = try decodeSnapshot()
        if snapshot.profiles.isEmpty {
            let initial = BrowserSnapshot.initial()
            try save(initial)
            return initial
        }
        return snapshot
    }

    func save(_ snapshot: BrowserSnapshot) throws {
        guard didLoadStores else { throw BrowserPersistenceError.storeNotLoaded }
        let now = Date.now
        let context = container.viewContext

        try replace(
            kind: .profile,
            values: snapshot.profiles.filter { $0.storageMode == .persistent },
            id: { $0.id.rawValue.uuidString },
            modifiedAt: { $0.modifiedAt },
            entityName: Entity.synced,
            context: context,
            now: now
        )
        try replace(
            kind: .space,
            values: snapshot.spaces.filter { $0.storageMode == .persistent },
            id: { $0.id.rawValue.uuidString },
            modifiedAt: { $0.modifiedAt },
            entityName: Entity.synced,
            context: context,
            now: now
        )
        try replace(
            kind: .tab,
            values: snapshot.tabs.filter { $0.storageMode == .persistent },
            id: { $0.id.rawValue.uuidString },
            modifiedAt: { $0.modifiedAt },
            entityName: Entity.synced,
            context: context,
            now: now
        )
        let persistentProfileIDs = Set(
            snapshot.profiles
                .filter { $0.storageMode == .persistent }
                .map(\.id)
        )
        try replace(
            kind: .archivedTab,
            values: snapshot.archivedTabs.filter { persistentProfileIDs.contains($0.profileID) },
            id: { $0.id.rawValue.uuidString },
            modifiedAt: { $0.modifiedAt },
            entityName: Entity.synced,
            context: context,
            now: now
        )
        try replace(
            kind: .blockerSiteException,
            values: snapshot.blockerSiteExceptions.filter {
                persistentProfileIDs.contains($0.profileID)
                    && BlockerSitePolicy.normalizedHost($0.host) == $0.host
            },
            id: { $0.id.rawValue.uuidString },
            modifiedAt: { $0.modifiedAt },
            entityName: Entity.synced,
            context: context,
            now: now
        )
        try replace(
            kind: .bookmark,
            values: snapshot.bookmarks,
            id: { $0.id.rawValue.uuidString },
            modifiedAt: { $0.modifiedAt },
            entityName: Entity.synced,
            context: context,
            now: now
        )
        try replace(
            kind: .settings,
            values: [snapshot.settings],
            id: { _ in Self.settingsRecordID },
            modifiedAt: { $0.modifiedAt },
            entityName: Entity.synced,
            context: context,
            now: now
        )

        let historyDestination = snapshot.settings.historySyncEnabled ? Entity.synced : Entity.local
        let historySource = snapshot.settings.historySyncEnabled ? Entity.local : Entity.synced
        try replace(
            kind: .history,
            values: snapshot.history,
            id: { $0.id.rawValue.uuidString },
            modifiedAt: { $0.modifiedAt },
            entityName: historyDestination,
            context: context,
            now: now
        )
        try replace(
            kind: .history,
            values: [HistoryVisit](),
            id: { $0.id.rawValue.uuidString },
            modifiedAt: { $0.modifiedAt },
            entityName: historySource,
            context: context,
            now: now
        )

        try purgeExpiredTombstones(in: context, now: now)
        if context.hasChanges {
            try context.save()
        }
    }

    private func loadStores() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            var remaining = container.persistentStoreDescriptions.count
            var firstError: (any Error)?
            container.loadPersistentStores { _, error in
                if let error, firstError == nil {
                    firstError = error
                }
                remaining -= 1
                guard remaining == 0 else { return }
                if let firstError {
                    continuation.resume(throwing: firstError)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
        didLoadStores = true
        if cloudKitEnabled {
            publishSyncStatus(.starting)
            startCloudMonitoring()
            Task { @MainActor [weak self] in
                await self?.refreshCloudAccountStatus()
            }
        } else {
            publishSyncStatus(.localOnly)
        }
    }

    private func startCloudMonitoring() {
        if remoteChangeObserver == nil {
            remoteChangeObserver = NotificationObserverToken(NotificationCenter.default.addObserver(
                forName: .NSPersistentStoreRemoteChange,
                object: container.persistentStoreCoordinator,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.onExternalChange?()
                }
            })
        }
        if cloudEventObserver == nil {
            cloudEventObserver = NotificationObserverToken(NotificationCenter.default.addObserver(
                forName: NSPersistentCloudKitContainer.eventChangedNotification,
                object: container,
                queue: .main
            ) { [weak self] notification in
                guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event else { return }
                let hasEnded = event.endDate != nil
                let succeeded = event.succeeded
                MainActor.assumeIsolated {
                    self?.handleCloudEvent(hasEnded: hasEnded, succeeded: succeeded)
                }
            })
        }
        if accountChangeObserver == nil {
            accountChangeObserver = NotificationObserverToken(NotificationCenter.default.addObserver(
                forName: .CKAccountChanged,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.refreshCloudAccountStatus()
                }
            })
        }
    }

    private func handleCloudEvent(hasEnded: Bool, succeeded: Bool) {
        guard hasEnded else {
            publishSyncStatus(.syncing)
            return
        }
        if succeeded {
            publishSyncStatus(.available)
        } else {
            publishSyncStatus(.degraded("iCloud synchronization failed. Browsing continues with the local replica."))
        }
    }

    private func refreshCloudAccountStatus() async {
        guard let accountContainer else {
            publishSyncStatus(.localOnly)
            return
        }
        do {
            publishSyncStatus(Self.syncStatus(for: try await accountContainer.accountStatus()))
        } catch {
            publishSyncStatus(.degraded("Fireball could not determine iCloud availability. Browsing continues locally."))
        }
    }

    private func publishSyncStatus(_ status: BrowserSyncStatus) {
        syncStatus = status
        onSyncStatusChange?(status)
    }

    static func syncStatus(for accountStatus: CKAccountStatus) -> BrowserSyncStatus {
        switch accountStatus {
        case .available:
            .available
        case .noAccount:
            .degraded("Sign in to iCloud to synchronize metadata. Browsing continues locally.")
        case .restricted:
            .degraded("This device restricts iCloud access. Browsing continues locally.")
        case .temporarilyUnavailable:
            .degraded("iCloud is temporarily unavailable. Browsing continues locally.")
        case .couldNotDetermine:
            .degraded("Fireball could not determine iCloud availability. Browsing continues locally.")
        @unknown default:
            .degraded("iCloud status is unknown. Browsing continues locally.")
        }
    }

    private func decodeSnapshot() throws -> BrowserSnapshot {
        let context = container.viewContext
        let settings = try decodeLatest(BrowserSettings.self, kind: .settings, entityName: Entity.synced, context: context)
            .first ?? BrowserSettings()
        let historyEntity = settings.historySyncEnabled ? Entity.synced : Entity.local
        let cutoff = Date.now.addingTimeInterval(-90 * 24 * 60 * 60)
        let profiles = try decodeLatest(BrowserProfile.self, kind: .profile, entityName: Entity.synced, context: context)
        let persistentProfileIDs = Set(profiles.filter { $0.storageMode == .persistent }.map(\.id))
        let blockerSiteExceptions = try decodeLatest(
            BlockerSiteException.self,
            kind: .blockerSiteException,
            entityName: Entity.synced,
            context: context
        ).filter {
            persistentProfileIDs.contains($0.profileID)
                && BlockerSitePolicy.normalizedHost($0.host) == $0.host
        }

        return BrowserSnapshot(
            profiles: profiles,
            spaces: try decodeLatest(BrowserSpace.self, kind: .space, entityName: Entity.synced, context: context),
            tabs: try decodeLatest(BrowserTab.self, kind: .tab, entityName: Entity.synced, context: context),
            archivedTabs: try decodeLatest(
                ArchivedTab.self,
                kind: .archivedTab,
                entityName: Entity.synced,
                context: context
            ),
            blockerSiteExceptions: blockerSiteExceptions,
            bookmarks: try decodeLatest(Bookmark.self, kind: .bookmark, entityName: Entity.synced, context: context),
            history: try decodeLatest(HistoryVisit.self, kind: .history, entityName: historyEntity, context: context)
                .filter { $0.visitedAt >= cutoff },
            settings: settings
        )
    }

    private func replace<Value: Encodable>(
        kind: RecordKind,
        values: [Value],
        id: (Value) -> String,
        modifiedAt: (Value) -> Date,
        entityName: String,
        context: NSManagedObjectContext,
        now: Date
    ) throws {
        let existing = try records(kind: kind, entityName: entityName, context: context)
        var recordsByID = Dictionary(grouping: existing, by: { $0.value(forKey: "recordID") as? String ?? "" })
        let encoder = JSONEncoder.fireball

        for value in values {
            let recordID = id(value)
            let candidates = recordsByID.removeValue(forKey: recordID) ?? []
            let record = candidates.max(by: Self.isOlder)
                ?? NSEntityDescription.insertNewObject(forEntityName: entityName, into: context)
            for duplicate in candidates where duplicate !== record {
                duplicate.setValue(Data(), forKey: "payload")
                duplicate.setValue(now, forKey: "modifiedAt")
                duplicate.setValue(now, forKey: "deletedAt")
            }
            let storedModifiedAt = record.value(forKey: "modifiedAt") as? Date ?? .distantPast
            if record.value(forKey: "deletedAt") != nil || storedModifiedAt > modifiedAt(value) {
                continue
            }
            record.setValue(recordID, forKey: "recordID")
            record.setValue(kind.rawValue, forKey: "kind")
            record.setValue(try encoder.encode(value), forKey: "payload")
            record.setValue(modifiedAt(value), forKey: "modifiedAt")
            record.setValue(nil, forKey: "deletedAt")
        }

        for duplicates in recordsByID.values {
            for record in duplicates {
                record.setValue(Data(), forKey: "payload")
                record.setValue(now, forKey: "modifiedAt")
                record.setValue(now, forKey: "deletedAt")
            }
        }
    }

    private func decodeLatest<Value: Decodable>(
        _ type: Value.Type,
        kind: RecordKind,
        entityName: String,
        context: NSManagedObjectContext
    ) throws -> [Value] {
        let grouped = Dictionary(
            grouping: try records(kind: kind, entityName: entityName, context: context),
            by: { $0.value(forKey: "recordID") as? String ?? "" }
        )
        let decoder = JSONDecoder.fireball
        return try grouped.values.compactMap { candidates in
            guard let latest = candidates.max(by: Self.isOlder), latest.value(forKey: "deletedAt") == nil,
                  let payload = latest.value(forKey: "payload") as? Data, !payload.isEmpty else {
                return nil
            }
            return try decoder.decode(type, from: payload)
        }
    }

    private func records(
        kind: RecordKind,
        entityName: String,
        context: NSManagedObjectContext
    ) throws -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.predicate = NSPredicate(format: "kind == %@", kind.rawValue)
        return try context.fetch(request)
    }

    private func purgeExpiredTombstones(in context: NSManagedObjectContext, now: Date) throws {
        let cutoff = now.addingTimeInterval(-Self.tombstoneLifetime)
        for entityName in [Entity.synced, Entity.local] {
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            request.predicate = NSPredicate(format: "deletedAt < %@", cutoff as NSDate)
            for record in try context.fetch(request) {
                context.delete(record)
            }
        }
    }

    private static func isOlder(_ lhs: NSManagedObject, _ rhs: NSManagedObject) -> Bool {
        let lhsDate = lhs.value(forKey: "modifiedAt") as? Date ?? .distantPast
        let rhsDate = rhs.value(forKey: "modifiedAt") as? Date ?? .distantPast
        return lhsDate < rhsDate
    }

    private static func makeStoreDescriptions(inMemory: Bool, cloudKitEnabled: Bool) -> [NSPersistentStoreDescription] {
        let cloud = NSPersistentStoreDescription()
        cloud.configuration = Configuration.cloud
        let local = NSPersistentStoreDescription()
        local.configuration = Configuration.local

        if inMemory {
            cloud.type = NSInMemoryStoreType
            local.type = NSInMemoryStoreType
            cloud.url = URL(fileURLWithPath: "/tmp/fireball-cloud-\(UUID().uuidString)")
            local.url = URL(fileURLWithPath: "/tmp/fireball-local-\(UUID().uuidString)")
        } else {
            let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Fireball", isDirectory: true)
            try? FileManager.default.createDirectory(at: applicationSupport, withIntermediateDirectories: true)
            cloud.url = applicationSupport.appendingPathComponent("FireballCloud.sqlite")
            local.url = applicationSupport.appendingPathComponent("FireballLocal.sqlite")
        }

        cloud.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        if cloudKitEnabled {
            cloud.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: cloudContainerIdentifier
            )
            cloud.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        return [cloud, local]
    }

    private static func makeManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        let synced = makeRecordEntity(name: Entity.synced)
        let local = makeRecordEntity(name: Entity.local)
        model.entities = [synced, local]
        model.setEntities([synced], forConfigurationName: Configuration.cloud)
        model.setEntities([local], forConfigurationName: Configuration.local)
        return model
    }

    private static func makeRecordEntity(name: String) -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = name
        entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        entity.properties = [
            attribute(name: "recordID", type: .stringAttributeType, defaultValue: ""),
            attribute(name: "kind", type: .stringAttributeType, defaultValue: ""),
            attribute(name: "payload", type: .binaryDataAttributeType, defaultValue: Data()),
            attribute(name: "modifiedAt", type: .dateAttributeType, defaultValue: Date.distantPast),
            attribute(name: "deletedAt", type: .dateAttributeType, optional: true),
        ]
        return entity
    }

    private static func attribute(
        name: String,
        type: NSAttributeType,
        defaultValue: Any? = nil,
        optional: Bool = false
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.defaultValue = defaultValue
        attribute.isOptional = optional
        return attribute
    }
}

private final class NotificationObserverToken: @unchecked Sendable {
    private let token: NSObjectProtocol

    init(_ token: NSObjectProtocol) {
        self.token = token
    }

    deinit {
        NotificationCenter.default.removeObserver(token)
    }
}

enum BrowserPersistenceError: LocalizedError {
    case storeNotLoaded

    var errorDescription: String? {
        switch self {
        case .storeNotLoaded: "The browser data store is not ready."
        }
    }
}

private extension JSONEncoder {
    static var fireball: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}

private extension JSONDecoder {
    static var fireball: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }
}
