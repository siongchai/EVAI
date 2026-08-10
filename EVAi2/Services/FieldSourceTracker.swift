import Foundation

enum FieldSourceTracker {
    static func attributeFields(
        data: ExtractedSessionData,
        images: [CaptureImageItem]
    ) -> [ExtractionFieldKey: CaptureImageCategory?] {
        let available = Set(images.map(\.category))
        var sources: [ExtractionFieldKey: CaptureImageCategory?] = [:]

        for field in ExtractionFieldKey.allCases {
            guard fieldHasValue(field, in: data) else {
                sources[field] = nil
                continue
            }
            sources[field] = available.contains(.sessionPhoto)
                ? .sessionPhoto
                : preferredSource(for: field, available: available)
        }

        return sources
    }

    static func sourceLabel(for category: CaptureImageCategory?) -> String {
        category?.title ?? "Unknown"
    }

    private static func fieldHasValue(_ field: ExtractionFieldKey, in data: ExtractedSessionData) -> Bool {
        switch field {
        case .chargingLocation: data.chargingLocation?.isEmpty == false
        case .chargerId: data.chargerId?.isEmpty == false
        case .chargingNetwork: data.chargingNetwork?.isEmpty == false
        case .chargerType: data.chargerType?.isEmpty == false
        case .chargerPowerKW: data.chargerPowerKW != nil
        case .startDate: data.startDate?.isEmpty == false || data.startTime?.isEmpty == false
        case .endDate: data.endDate?.isEmpty == false || data.endTime?.isEmpty == false
        case .startSOCPercent: data.startSOCPercent != nil
        case .endSOCPercent: data.endSOCPercent != nil
        case .odometerKM: data.odometerKM != nil
        case .energyKWh: data.energyKWh != nil
        case .amountSGD: data.amountSGD != nil
        case .sessionDuration: data.sessionDuration?.isEmpty == false
        case .idleDuration: data.idleDuration?.isEmpty == false
        case .carModel: data.carModel?.isEmpty == false
        }
    }

    private static func preferredSource(
        for field: ExtractionFieldKey,
        available: Set<CaptureImageCategory>
    ) -> CaptureImageCategory? {
        let preferences: [CaptureImageCategory]
        switch field {
        case .startSOCPercent, .odometerKM:
            preferences = [.dashboardBefore, .dashboardAfter, .appScreenshot]
        case .endSOCPercent:
            preferences = [.dashboardAfter, .dashboardBefore, .appScreenshot]
        case .energyKWh, .amountSGD:
            preferences = [.receipt, .appScreenshot, .chargerScreen]
        case .chargingLocation, .chargerId, .chargingNetwork, .chargerType, .chargerPowerKW:
            preferences = [.chargerScreen, .appScreenshot, .receipt]
        case .startDate, .endDate, .sessionDuration, .idleDuration:
            preferences = [.appScreenshot, .chargerScreen, .receipt]
        case .carModel:
            preferences = [.dashboardBefore, .dashboardAfter, .appScreenshot]
        }

        return preferences.first { available.contains($0) } ?? available.first
    }
}
