import Foundation
import SwiftData

@Model
final class ChargingSession {
    var id: UUID = Foundation.UUID()
    var chargingLocation: String = ""
    var chargerId: String = ""
    var chargingNetwork: String = ""
    var chargerType: String = ""
    var chargerPowerKW: Double = 0
    var startDate: Date = Foundation.Date.now
    var endDate: Date = Foundation.Date.now
    var startSOCPercent: Double = 0
    var endSOCPercent: Double = 0
    var odometerKM: Double = 0
    var energyKWh: Double = 0
    var amountSGD: Double = 0
    var sessionDuration: Int = 0
    var idleDuration: Int = 0
    var carModel: String = ""
    var extractionConfidence: Double = 0
    var rawAIResponse: String = ""
    var sourceImageIDs: String = ""
    var createdAt: Date = Foundation.Date.now
    var updatedAt: Date = Foundation.Date.now

    init(
        id: UUID = UUID(),
        chargingLocation: String,
        chargerId: String,
        chargingNetwork: String,
        chargerType: String,
        chargerPowerKW: Double,
        startDate: Date,
        endDate: Date,
        startSOCPercent: Double,
        endSOCPercent: Double,
        odometerKM: Double,
        energyKWh: Double,
        amountSGD: Double,
        sessionDuration: Int,
        idleDuration: Int,
        carModel: String,
        extractionConfidence: Double,
        rawAIResponse: String = "",
        sourceImageIDs: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.chargingLocation = chargingLocation
        self.chargerId = chargerId
        self.chargingNetwork = chargingNetwork
        self.chargerType = chargerType
        self.chargerPowerKW = chargerPowerKW
        self.startDate = startDate
        self.endDate = endDate
        self.startSOCPercent = startSOCPercent
        self.endSOCPercent = endSOCPercent
        self.odometerKM = odometerKM
        self.energyKWh = energyKWh
        self.amountSGD = amountSGD
        self.sessionDuration = sessionDuration
        self.idleDuration = idleDuration
        self.carModel = carModel
        self.extractionConfidence = extractionConfidence
        self.rawAIResponse = rawAIResponse
        self.sourceImageIDs = sourceImageIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var costPerKWh: Double {
        guard energyKWh > 0 else { return 0 }
        return amountSGD / energyKWh
    }

    /// Active charging time in seconds: total session duration minus idle.
    var chargingDurationSeconds: Int {
        max(0, sessionDuration - idleDuration)
    }

    var networkInitials: String {
        chargingNetwork
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()
            .uppercased()
    }

    var sourceImageIDList: [String] {
        sourceImageIDs
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var decryptedRawAIResponse: String {
        CrashRecoveryService.recoverRawResponse(self)
    }
}
