import Foundation
import Observation
import SwiftData

struct AppSettingsExport: Codable {
    var theme: String
    var confidenceThreshold: Double
    var autoReviewEnergy: Bool
    var autoReviewAmount: Bool
    var autoReviewSOCValues: Bool
    var autoReviewSessionDuration: Bool
    var autoReviewOdometer: Bool
    var showFieldSources: Bool
    var usesCustomPrompt: Bool
    var hasOpenAIKey: Bool
    var hasClaudeKey: Bool
    var preferredCloudProvider: String
    var storageUsageBytes: Int64
    var exportedAt: Date
}

@Observable
@MainActor
final class SettingsViewModel {
    var settings: AISettings?
    var openAIKeyInput = ""
    var claudeKeyInput = ""
    var openAIKeySaved = false
    var claudeKeySaved = false
    var openAIKeyError: String?
    var claudeKeyError: String?

    /// Legacy alias used by older UI bindings.
    var apiKeyInput: String {
        get { openAIKeyInput }
        set { openAIKeyInput = newValue }
    }

    var apiKeySaved: Bool {
        get { openAIKeySaved }
        set { openAIKeySaved = newValue }
    }

    var apiKeyError: String? {
        get { openAIKeyError }
        set { openAIKeyError = newValue }
    }

    var promptOverride: String {
        get { PromptManager.customPromptOverride }
        set { PromptManager.saveCustomPrompt(newValue) }
    }

    var effectiveExtractionPrompt: String {
        PromptManager.effectivePrompt
    }

    var isUsingDefaultPrompt: Bool {
        PromptManager.isUsingDefaultPrompt
    }

    var hasStoredOpenAIKey: Bool {
        SecureKeyManager.hasAPIKey(for: .openAI)
    }

    var hasStoredClaudeKey: Bool {
        SecureKeyManager.hasAPIKey(for: .claude)
    }

    var hasStoredAPIKey: Bool {
        hasStoredOpenAIKey
    }

    var preferredCloudProvider: CloudExtractionProvider {
        settings?.cloudProvider ?? CloudExtractionPreferences.preferred
    }

    var formattedStorageUsage: String {
        ImageStorageManager.formattedDiskUsage()
    }

    func bind(settings: AISettings) {
        self.settings = settings
        CloudExtractionPreferences.preferred = settings.cloudProvider
    }

    func restoreDefaultPrompt() {
        PromptManager.restoreDefault()
    }

    func saveOpenAIKey() {
        openAIKeyError = nil
        do {
            try SecureKeyManager.saveAPIKey(openAIKeyInput, provider: .openAI)
            openAIKeyInput = ""
            openAIKeySaved = true
        } catch {
            openAIKeyError = error.localizedDescription
            openAIKeySaved = false
        }
    }

    func deleteOpenAIKey() {
        openAIKeyError = nil
        do {
            try SecureKeyManager.deleteAPIKey(for: .openAI)
            openAIKeyInput = ""
            openAIKeySaved = false
        } catch {
            openAIKeyError = error.localizedDescription
        }
    }

    func saveClaudeKey() {
        claudeKeyError = nil
        do {
            try SecureKeyManager.saveAPIKey(claudeKeyInput, provider: .claude)
            claudeKeyInput = ""
            claudeKeySaved = true
        } catch {
            claudeKeyError = error.localizedDescription
            claudeKeySaved = false
        }
    }

    func deleteClaudeKey() {
        claudeKeyError = nil
        do {
            try SecureKeyManager.deleteAPIKey(for: .claude)
            claudeKeyInput = ""
            claudeKeySaved = false
        } catch {
            claudeKeyError = error.localizedDescription
        }
    }

    func saveAPIKey() {
        saveOpenAIKey()
    }

    func deleteAPIKey() {
        deleteOpenAIKey()
    }

    func updatePreferredCloudProvider(_ provider: CloudExtractionProvider) {
        settings?.cloudProvider = provider
        CloudExtractionPreferences.preferred = provider
        touchSettings()
    }

    func clearImageCache() {
        ImageStorageManager.clearCache()
        BackgroundTaskManager.cleanTemporaryFiles()
    }

    func deleteAllLocalData(using modelContext: ModelContext) throws {
        try ModelContainerFactory.deleteAllLocalData(context: modelContext)
        AnalyticsCacheService.clear()
        ErrorLogger.clearLog()
    }

    func pendingExtractionCount(in context: ModelContext) -> Int {
        ExtractionQueueService.pendingItems(from: context).count
    }

    func exportSettingsSnapshot(settings: AISettings?) -> AppSettingsExport {
        AppSettingsExport(
            theme: UserDefaults.standard.string(forKey: "evai.app.theme") ?? AppTheme.system.rawValue,
            confidenceThreshold: settings?.confidenceThreshold ?? 0.85,
            autoReviewEnergy: settings?.autoReviewEnergy ?? true,
            autoReviewAmount: settings?.autoReviewAmount ?? true,
            autoReviewSOCValues: settings?.autoReviewSOCValues ?? true,
            autoReviewSessionDuration: settings?.autoReviewSessionDuration ?? true,
            autoReviewOdometer: settings?.autoReviewOdometer ?? true,
            showFieldSources: settings?.showFieldSources ?? true,
            usesCustomPrompt: !PromptManager.isUsingDefaultPrompt,
            hasOpenAIKey: SecureKeyManager.hasAPIKey(for: .openAI),
            hasClaudeKey: SecureKeyManager.hasAPIKey(for: .claude),
            preferredCloudProvider: settings?.preferredCloudProvider ?? CloudExtractionProvider.openAI.rawValue,
            storageUsageBytes: ImageStorageManager.totalDiskUsage(),
            exportedAt: .now
        )
    }

    func writeSettingsExport(_ snapshot: AppSettingsExport) -> URL? {
        guard let data = try? JSONEncoder().encode(snapshot) else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("EVAi-Settings-\(Int(Date().timeIntervalSince1970)).json")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            ErrorLogger.log("Settings export failed", category: .general, error: error)
            return nil
        }
    }

    func updateConfidenceThreshold(_ value: Double) {
        settings?.confidenceThreshold = value
        touchSettings()
    }

    func updateAutoReviewEnergy(_ value: Bool) {
        settings?.autoReviewEnergy = value
        touchSettings()
    }

    func updateAutoReviewAmount(_ value: Bool) {
        settings?.autoReviewAmount = value
        touchSettings()
    }

    func updateAutoReviewSOCValues(_ value: Bool) {
        settings?.autoReviewSOCValues = value
        touchSettings()
    }

    func updateAutoReviewSessionDuration(_ value: Bool) {
        settings?.autoReviewSessionDuration = value
        touchSettings()
    }

    func updateAutoReviewOdometer(_ value: Bool) {
        settings?.autoReviewOdometer = value
        touchSettings()
    }

    func updateShowFieldSources(_ value: Bool) {
        settings?.showFieldSources = value
        touchSettings()
    }

    func save(using modelContext: ModelContext) throws {
        touchSettings()
        try modelContext.save()
    }

    private func touchSettings() {
        settings?.updatedAt = .now
    }
}
