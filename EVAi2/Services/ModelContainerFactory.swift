import Foundation
import SwiftData

enum ModelContainerFactory {
    private static let storeName = "EVAi"
    private static let appGroupIdentifier = "group.sg.tsc.EVAi2"
    private static let schemaVersionKey = "evai.swiftdata.schema.version"
    private static let currentSchemaVersion = 7

    static func make(allowRecovery: Bool = true) throws -> ModelContainer {
        let schema = Schema([
            ChargingSession.self,
            Car.self,
            AISettings.self,
            PendingExtraction.self,
            UserProfile.self
        ])

        let storeURL = persistentStoreURL()
        try ensureDirectoryExists(at: storeURL.deletingLastPathComponent())

        let configuration = ModelConfiguration(
            storeName,
            schema: schema,
            url: storeURL
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            noteSuccessfulSchemaVersion()
            return container
        } catch {
            ErrorLogger.log("ModelContainer creation failed", category: .database, error: error)
            guard allowRecovery else { throw error }
            deleteIncompatibleStoresForRecovery()
            try ensureDirectoryExists(at: storeURL.deletingLastPathComponent())
            let container = try ModelContainer(for: schema, configurations: [configuration])
            noteSuccessfulSchemaVersion()
            return container
        }
    }

    static func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([
            ChargingSession.self,
            Car.self,
            AISettings.self,
            PendingExtraction.self,
            UserProfile.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func deleteIncompatibleStoresForRecovery() {
        let fileManager = FileManager.default
        let storeNames = [storeName, "default"]

        for directory in storeDirectories() {
            for name in storeNames {
                for suffix in ["", "-shm", "-wal"] {
                    let url = directory.appendingPathComponent("\(name).store\(suffix)")
                    try? fileManager.removeItem(at: url)
                }
            }

            guard let contents = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            ) else {
                continue
            }

            for url in contents where url.lastPathComponent.hasSuffix(".store")
                || url.lastPathComponent.hasSuffix(".store-shm")
                || url.lastPathComponent.hasSuffix(".store-wal") {
                try? fileManager.removeItem(at: url)
            }
        }
    }

    static func deleteAllLocalData(context: ModelContext) throws {
        try context.delete(model: ChargingSession.self)
        try context.delete(model: Car.self)
        try context.delete(model: PendingExtraction.self)
        try context.delete(model: UserProfile.self)
        try context.save()
        ImageStorageManager.clearCache()
        AnalyticsCacheService.clear()
        WidgetDataStore.sync(from: [])
        try SecureKeyManager.deleteAllAPIKeys()
        PromptManager.restoreDefault()
    }

    /// Records the schema generation for diagnostics only. Data is preserved across app updates
    /// via SwiftData lightweight migration; the store is wiped only when opening it fails.
    private static func noteSuccessfulSchemaVersion() {
        UserDefaults.standard.set(currentSchemaVersion, forKey: schemaVersionKey)
    }

    private static func persistentStoreURL() -> URL {
        let supportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory

        return supportURL.appendingPathComponent("\(storeName).store")
    }

    private static func storeDirectories() -> [URL] {
        var directories: [URL] = []

        if let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first {
            directories.append(appSupport)
        }

        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) {
            directories.append(groupURL.appendingPathComponent("Library/Application Support", isDirectory: true))
        }

        return directories
    }

    private static func ensureDirectoryExists(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
