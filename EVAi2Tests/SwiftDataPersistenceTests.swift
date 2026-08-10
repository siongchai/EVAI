import XCTest
import SwiftData
@testable import EVAi2

final class SwiftDataPersistenceTests: XCTestCase {
    @MainActor
    func testChargingSessionPersistsInMemoryContainer() throws {
        let schema = Schema([
            ChargingSession.self,
            Car.self,
            AISettings.self,
            PendingExtraction.self,
            UserProfile.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext

        let session = ChargingSession(
            chargingLocation: "Test Location",
            chargerId: "A1",
            chargingNetwork: "Charge+",
            chargerType: "DC",
            chargerPowerKW: 50,
            startDate: .now,
            endDate: .now,
            startSOCPercent: 10,
            endSOCPercent: 70,
            odometerKM: 5000,
            energyKWh: 30,
            amountSGD: 14,
            sessionDuration: 3600,
            idleDuration: 0,
            carModel: "BYD Atto 3",
            extractionConfidence: 0.88,
            sourceImageIDs: "image-1,image-2"
        )

        context.insert(session)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<ChargingSession>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.sourceImageIDList.count, 2)
        XCTAssertEqual(fetched.first?.chargingLocation, "Test Location")
    }

    @MainActor
    func testPersistentContainerFactoryCreatesStore() throws {
        let container = try ModelContainerFactory.make(allowRecovery: true)
        let context = container.mainContext

        let profile = UserProfile(fullName: "Test User", email: "test@example.com")
        context.insert(profile)
        try context.save()

        let fetched = try context.fetch(
            FetchDescriptor<UserProfile>(
                predicate: #Predicate { $0.email == "test@example.com" }
            )
        )
        XCTAssertEqual(fetched.first?.fullName, "Test User")
    }
}
