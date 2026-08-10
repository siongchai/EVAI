import XCTest
import SwiftData
@testable import EVAi2

final class ImageStorageManagerTests: XCTestCase {
    @MainActor
    func testProtectedImageIDsIncludesProfileAndCarPhotos() throws {
        let schema = Schema([
            ChargingSession.self,
            Car.self,
            UserProfile.self
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext

        let profile = UserProfile(fullName: "Alex", email: "alex@example.com")
        profile.imageFileID = "profile-AAA"
        context.insert(profile)

        let car = Car(make: "Tesla", modelName: "Model 3", variant: "LR")
        car.imageFileID = "car-BBB"
        context.insert(car)

        let session = ChargingSession(
            chargingLocation: "Test",
            chargerId: "A1",
            chargingNetwork: "SP",
            chargerType: "AC Charger",
            chargerPowerKW: 22,
            startDate: .now,
            endDate: .now,
            startSOCPercent: 20,
            endSOCPercent: 80,
            odometerKM: 1000,
            energyKWh: 10,
            amountSGD: 5,
            sessionDuration: 3600,
            idleDuration: 0,
            carModel: "Tesla Model 3",
            extractionConfidence: 0.9,
            sourceImageIDs: "session-CCC"
        )
        context.insert(session)
        try context.save()

        let protected = ImageStorageManager.protectedImageIDs(from: context)

        XCTAssertTrue(protected.contains("profile-AAA"))
        XCTAssertTrue(protected.contains("car-BBB"))
        XCTAssertTrue(protected.contains("session-CCC"))
    }

    @MainActor
    func testDeleteOrphansKeepsProfileAndCarPhotos() throws {
        ImageStorageManager.prepareStorageIfNeeded()

        let profileUUID = UUID()
        let carUUID = UUID()
        let orphanUUID = UUID()

        let sample = UIImage(systemName: "person.fill")!
        let data = sample.jpegData(compressionQuality: 0.9)!
        let profileID = try ImageStorageManager.saveProfilePhoto(data, profileID: profileUUID)
        let carID = try ImageStorageManager.saveCarPhoto(data, carID: carUUID)
        _ = try ImageStorageManager.saveProfilePhoto(data, profileID: orphanUUID)

        let schema = Schema([UserProfile.self, Car.self, ChargingSession.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext

        let profile = UserProfile(fullName: "Alex", email: "alex@example.com")
        profile.imageFileID = profileID
        context.insert(profile)

        let car = Car(make: "Tesla", modelName: "Model 3", variant: "LR")
        car.imageFileID = carID
        context.insert(car)
        try context.save()

        ImageStorageManager.deleteOrphans(validIDs: ImageStorageManager.protectedImageIDs(from: context))

        XCTAssertTrue(ImageStorageManager.storedImageExists(id: profileID))
        XCTAssertTrue(ImageStorageManager.storedImageExists(id: carID))
        XCTAssertFalse(ImageStorageManager.storedImageExists(id: "profile-\(orphanUUID.uuidString)"))
    }
}
