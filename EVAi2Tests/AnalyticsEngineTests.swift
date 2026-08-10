import XCTest
@testable import EVAi2

final class AnalyticsEngineTests: XCTestCase {
    func testMonthlyMetricsAggregatesSessions() {
        let month = Date.now.startOfMonth
        let sessions = [
            makeSession(startDate: month, amount: 10, energy: 20),
            makeSession(startDate: month, amount: 15, energy: 30)
        ]

        let metrics = AnalyticsEngine.monthlyMetrics(from: sessions, month: month)
        XCTAssertEqual(metrics.totalCost, 25, accuracy: 0.01)
        XCTAssertEqual(metrics.totalEnergy, 50, accuracy: 0.01)
        XCTAssertEqual(metrics.sessionCount, 2)
        XCTAssertEqual(metrics.averageCostPerKWh, 0.5, accuracy: 0.01)
    }

    func testAverageCostPerKWhUsesTotalCostAndEnergy() {
        let month = Date.now.startOfMonth
        let sessions = [
            makeSession(startDate: month, amount: 10, energy: 0),
            makeSession(startDate: month, amount: 12, energy: 24)
        ]

        let average = AnalyticsEngine.calculateAverageCostPerKWh(from: sessions, month: month)
        XCTAssertEqual(average, 22.0 / 24.0, accuracy: 0.01)
    }

    private func makeSession(startDate: Date, amount: Double, energy: Double) -> ChargingSession {
        ChargingSession(
            chargingLocation: "Test",
            chargerId: "T1",
            chargingNetwork: "SP Group",
            chargerType: "AC",
            chargerPowerKW: 7,
            startDate: startDate,
            endDate: startDate,
            startSOCPercent: 20,
            endSOCPercent: 80,
            odometerKM: 1000,
            energyKWh: energy,
            amountSGD: amount,
            sessionDuration: 3600,
            idleDuration: 0,
            carModel: "Tesla Model 3",
            extractionConfidence: 0.9
        )
    }
}
