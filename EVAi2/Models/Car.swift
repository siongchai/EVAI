import Foundation
import SwiftData
import UIKit

@Model
final class Car {
    var id: UUID = Foundation.UUID()
    var carName: String = ""
    var make: String = ""
    var modelName: String = ""
    var variant: String = ""
    var batterySizeKWh: Double = 0
    var initialOdometerKM: Double = 0
    var initialSOCPercent: Double = 0
    var collectionDate: Date?
    var licensePlate: String = ""
    var purchasePriceSGD: Double = 0
    var isPrimary: Bool = false
    var imageFileID: String = ""
    var createdAt: Date = Foundation.Date.now
    var updatedAt: Date = Foundation.Date.now

    init(
        id: UUID = UUID(),
        carName: String = "",
        make: String,
        modelName: String,
        variant: String,
        batterySizeKWh: Double = 0,
        initialOdometerKM: Double = 0,
        initialSOCPercent: Double = 0,
        collectionDate: Date? = nil,
        licensePlate: String = "",
        purchasePriceSGD: Double = 0,
        isPrimary: Bool = false,
        imageFileID: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.carName = carName
        self.make = make
        self.modelName = modelName
        self.variant = variant
        self.batterySizeKWh = batterySizeKWh
        self.initialOdometerKM = initialOdometerKM
        self.initialSOCPercent = initialSOCPercent
        self.collectionDate = collectionDate
        self.licensePlate = licensePlate
        self.purchasePriceSGD = purchasePriceSGD
        self.isPrimary = isPrimary
        self.imageFileID = imageFileID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var displayName: String {
        if !carName.trimmingCharacters(in: .whitespaces).isEmpty {
            return carName
        }
        return "\(make) \(modelName) \(variant)".trimmingCharacters(in: .whitespaces)
    }

    var photoImage: UIImage? {
        guard !imageFileID.isEmpty else { return nil }
        return ImageStorageManager.loadDisplayImage(id: imageFileID)
    }
}
