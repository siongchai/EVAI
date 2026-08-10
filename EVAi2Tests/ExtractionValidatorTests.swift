import XCTest
@testable import EVAi2

final class ExtractionValidatorTests: XCTestCase {
    func testValidSessionProducesNoErrors() {
        let data = ExtractedSessionData(
            chargingLocation: "Marina Bay",
            chargerId: "SP-001",
            chargingNetwork: "SP Group",
            chargerType: "DC Fast",
            chargerPowerKW: 120,
            startDate: "2026-06-01",
            startTime: "10:00",
            endDate: "2026-06-01",
            endTime: "11:00",
            startSOCPercent: 20,
            endSOCPercent: 80,
            odometerKM: 10000,
            energyKWh: 42,
            amountSGD: 18.5,
            sessionDuration: "60",
            idleDuration: "0",
            carModel: "Tesla Model 3",
            extractionConfidence: 0.92
        )

        let result = ExtractionValidator.validateSession(data)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testNegativeEnergyProducesError() {
        let data = ExtractedSessionData(
            chargingLocation: "Test",
            chargerId: nil,
            chargingNetwork: nil,
            chargerType: nil,
            chargerPowerKW: nil,
            startDate: nil,
            startTime: nil,
            endDate: nil,
            endTime: nil,
            startSOCPercent: nil,
            endSOCPercent: nil,
            odometerKM: nil,
            energyKWh: -5,
            amountSGD: 10,
            sessionDuration: nil,
            idleDuration: nil,
            carModel: nil,
            extractionConfidence: 0.5
        )

        let result = ExtractionValidator.validateSession(data)
        XCTAssertFalse(result.warnings.isEmpty)
    }
}
