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

enum WidgetDataStore {
    static let appGroupIdentifier = "group.sg.tsc.EVAi2"
    static let snapshotFileName = "widget-snapshot.json"

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    static var snapshotFileURL: URL? {
        containerURL?.appendingPathComponent(snapshotFileName)
    }

    static func sync(from sessions: [ChargingSession]) {
        let month = Date.now.startOfMonth
        let monthSessions = sessions.filter { $0.startDate.isSameMonth(as: month) }
        let lastSession = sessions.sorted { $0.startDate > $1.startDate }.first

        let snapshot = WidgetSnapshot(
            monthlyCost: monthSessions.reduce(0) { $0 + $1.amountSGD },
            monthlyEnergy: monthSessions.reduce(0) { $0 + $1.energyKWh },
            lastSessionLocation: lastSession?.chargingLocation ?? "No sessions yet",
            lastSessionCost: lastSession?.amountSGD ?? 0,
            lastSessionEnergy: lastSession?.energyKWh ?? 0,
            lastSessionDate: lastSession?.startDate ?? .now,
            updatedAt: .now
        )

        write(snapshot)
    }

    static func loadSnapshot() -> WidgetSnapshot {
        readFromFile() ?? .empty
    }

    static func ensureSnapshotExists() {
        guard readFromFile() == nil else { return }
        write(.empty)
    }

    private static func write(_ snapshot: WidgetSnapshot) {
        guard let url = snapshotFileURL,
              let data = try? JSONEncoder().encode(snapshot) else {
            return
        }

        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: [.atomic])
        } catch {
            ErrorLogger.log("Widget snapshot write failed", category: .storage, error: error)
        }
    }

    private static func readFromFile() -> WidgetSnapshot? {
        guard let url = snapshotFileURL,
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return nil
        }
        return snapshot
    }
}
