import Foundation

struct WidgetSnapshot: Codable {
    var monthlyCost: Double
    var monthlyEnergy: Double
    var lastSessionLocation: String
    var lastSessionCost: Double
    var lastSessionEnergy: Double
    var lastSessionDate: Date
    var updatedAt: Date

    static let empty = WidgetSnapshot(
        monthlyCost: 0,
        monthlyEnergy: 0,
        lastSessionLocation: "No sessions yet",
        lastSessionCost: 0,
        lastSessionEnergy: 0,
        lastSessionDate: .now,
        updatedAt: .now
    )
}

enum WidgetSnapshotReader {
    private static let appGroupIdentifier = "group.sg.tsc.EVAi2"
    private static let snapshotFileName = "widget-snapshot.json"

    static func load() -> WidgetSnapshot {
        guard let url = snapshotFileURL(),
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }

    private static func snapshotFileURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(snapshotFileName)
    }
}
