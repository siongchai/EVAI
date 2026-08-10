import Foundation
import SwiftData

@Model
final class AISettings {
    var id: UUID = Foundation.UUID()
    var confidenceThreshold: Double = 0.85
    var autoReviewEnergy: Bool = true
    var autoReviewAmount: Bool = true
    var autoReviewSOCValues: Bool = true
    var autoReviewSessionDuration: Bool = true
    var autoReviewOdometer: Bool = false
    var showFieldSources: Bool = true
    var preferredCloudProvider: String = CloudExtractionProvider.openAI.rawValue
    var updatedAt: Date = Foundation.Date.now

    init(
        id: UUID = UUID(),
        confidenceThreshold: Double = 0.85,
        autoReviewEnergy: Bool = true,
        autoReviewAmount: Bool = true,
        autoReviewSOCValues: Bool = true,
        autoReviewSessionDuration: Bool = true,
        autoReviewOdometer: Bool = false,
        showFieldSources: Bool = true,
        preferredCloudProvider: String = CloudExtractionProvider.openAI.rawValue,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.confidenceThreshold = confidenceThreshold
        self.autoReviewEnergy = autoReviewEnergy
        self.autoReviewAmount = autoReviewAmount
        self.autoReviewSOCValues = autoReviewSOCValues
        self.autoReviewSessionDuration = autoReviewSessionDuration
        self.autoReviewOdometer = autoReviewOdometer
        self.showFieldSources = showFieldSources
        self.preferredCloudProvider = preferredCloudProvider
        self.updatedAt = updatedAt
    }

    var cloudProvider: CloudExtractionProvider {
        get { CloudExtractionProvider(rawValue: preferredCloudProvider) ?? .openAI }
        set { preferredCloudProvider = newValue.rawValue }
    }

    static func defaults() -> AISettings {
        let settings = AISettings()
        CloudExtractionPreferences.preferred = settings.cloudProvider
        return settings
    }
}
