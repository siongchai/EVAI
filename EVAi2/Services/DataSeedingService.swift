import Foundation
import SwiftData

@MainActor
enum DataSeedingService {
    private static let removedSampleSessionsKey = "evai.removedSampleSessions"

    private static let legacySampleChargerIDs: Set<String> = [
        "SP-TMP-042", "CP-VIV-118", "SH-PNG-007", "SP-BDK-021", "HOME-001",
        "CP-JP-033", "SP-ORC-009", "SH-WDL-014", "CP-MB-056", "SP-AMK-017"
    ]

    static func seedIfNeeded(modelContext: ModelContext) {
        removeLegacySampleSessionsIfNeeded(in: modelContext)
        seedAISettingsIfNeeded(into: modelContext)
        ensureUserProfile(into: modelContext)
        try? modelContext.save()
    }

    static func ensureUserProfile(into context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<UserProfile>())) ?? 0
        guard count == 0 else { return }
        context.insert(UserProfile(fullName: AppConstants.defaultUserName, email: ""))
    }

    private static func seedAISettingsIfNeeded(into context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<AISettings>())) ?? 0
        guard count == 0 else { return }
        context.insert(AISettings.defaults())
    }

    private static func removeLegacySampleSessionsIfNeeded(in context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: removedSampleSessionsKey) else { return }

        guard let sessions = try? context.fetch(FetchDescriptor<ChargingSession>()) else { return }

        var removedAny = false
        for session in sessions where legacySampleChargerIDs.contains(session.chargerId) {
            context.delete(session)
            removedAny = true
        }

        if removedAny {
            try? context.save()
        }

        UserDefaults.standard.set(true, forKey: removedSampleSessionsKey)
    }
}
