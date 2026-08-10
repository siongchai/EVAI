import Foundation
import Observation
import SwiftData
import UIKit

@Observable
@MainActor
final class CarManagementViewModel {
    var carName = ""
    var modelName = ""
    var variant = ""
    var batterySizeText = ""
    var initialOdometerText = ""
    var initialSOCText = ""
    var collectionDate = Date()
    var licensePlateText = ""
    var purchasePriceText = ""
    var isPrimary = false
    var editingCar: Car?
    var errorMessage: String?

    var photoPreview: UIImage?
    var pendingPhotoData: Data?
    var removeExistingPhoto = false

    var brandSelection = ""
    var customBrandText = ""
    var modelSelection = ""
    var customModelText = ""
    var variantSelection = ""
    var customVariantText = ""
    private var carNameIsCustomized = false

    var showsModelCatalog: Bool {
        !brandSelection.isEmpty
            && brandSelection != CarBrandCatalog.other
            && CarModelCatalog.hasCatalogModels(for: brandSelection)
    }

    var showsVariantCatalog: Bool {
        let brand = resolvedBrand.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = resolvedModelName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !brand.isEmpty, !model.isEmpty else { return false }
        return CarVariantCatalog.hasCatalogVariants(for: brand, model: model)
    }

    func handleBrandChanged() {
        guard showsModelCatalog else {
            modelSelection = ""
            clearVariantFields()
            return
        }

        let models = CarModelCatalog.models(for: brandSelection)
        if modelSelection != CarModelCatalog.other, !models.contains(modelSelection) {
            modelSelection = ""
            customModelText = ""
        }
        handleModelChanged()
    }

    func handleModelChanged() {
        if showsVariantCatalog {
            let brand = resolvedBrand.trimmingCharacters(in: .whitespacesAndNewlines)
            let model = resolvedModelName.trimmingCharacters(in: .whitespacesAndNewlines)
            let variants = CarVariantCatalog.variants(for: brand, model: model)
            if variantSelection != CarVariantCatalog.other, !variants.contains(variantSelection) {
                variantSelection = ""
                customVariantText = ""
            }
        } else {
            clearVariantFields()
        }
        applySuggestedCarNameIfNeeded()
    }

    func applySuggestedCarNameIfNeeded() {
        guard !carNameIsCustomized, let suggested = suggestedCarName else { return }
        carName = suggested
    }

    func handleCarNameEdited(_ newValue: String) {
        if newValue == suggestedCarName {
            carNameIsCustomized = false
        } else {
            carNameIsCustomized = true
        }
    }

    func beginEditing(_ car: Car) {
        editingCar = car
        carName = car.carName
        modelName = car.modelName
        variant = car.variant
        batterySizeText = car.batterySizeKWh > 0 ? String(format: "%.1f", car.batterySizeKWh) : ""
        initialOdometerText = car.initialOdometerKM > 0 ? String(format: "%.0f", car.initialOdometerKM) : ""
        initialSOCText = car.initialSOCPercent > 0 ? String(format: "%.0f", car.initialSOCPercent) : ""
        collectionDate = car.collectionDate ?? Date()
        licensePlateText = car.licensePlate
        purchasePriceText = car.purchasePriceSGD > 0 ? String(format: "%.2f", car.purchasePriceSGD) : ""
        isPrimary = car.isPrimary
        syncBrandFields(from: car.make)
        syncModelFields(from: car.modelName, brand: car.make)
        syncVariantFields(from: car.variant, brand: car.make, model: car.modelName)
        if let suggested = suggestedCarName, car.carName == suggested {
            carNameIsCustomized = false
        } else {
            carNameIsCustomized = !car.carName.isEmpty
        }
        photoPreview = car.photoImage
        pendingPhotoData = nil
        removeExistingPhoto = false
    }

    func resetForm() {
        editingCar = nil
        carName = ""
        modelName = ""
        variant = ""
        batterySizeText = ""
        initialOdometerText = ""
        initialSOCText = ""
        collectionDate = Date()
        licensePlateText = ""
        purchasePriceText = ""
        isPrimary = false
        errorMessage = nil
        brandSelection = ""
        customBrandText = ""
        modelSelection = ""
        customModelText = ""
        variantSelection = ""
        customVariantText = ""
        carNameIsCustomized = false
        photoPreview = nil
        pendingPhotoData = nil
        removeExistingPhoto = false
    }

    func setPhoto(from data: Data) {
        pendingPhotoData = (try? ImageProcessor.optimizeForPortrait(data)) ?? data
        photoPreview = ImageProcessor.makeThumbnail(from: pendingPhotoData ?? data)
        removeExistingPhoto = false
        errorMessage = nil
    }

    func removePhoto() {
        pendingPhotoData = nil
        photoPreview = nil
        removeExistingPhoto = true
    }

    func save(using modelContext: ModelContext, existingCars: [Car]) throws {
        let resolvedMake = resolvedBrand.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedModel = resolvedModelName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedVariant = resolvedVariantName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = carName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmedName.isEmpty ? (suggestedCarName ?? "") : trimmedName
        guard !resolvedMake.isEmpty,
              !resolvedModel.isEmpty else {
            errorMessage = "Brand and model are required."
            throw CarManagementError.validationFailed
        }

        let battery = Double(batterySizeText) ?? 0
        let initialOdometer = Double(initialOdometerText) ?? 0
        let initialSOC = Double(initialSOCText) ?? 0
        let purchasePrice = Double(purchasePriceText) ?? 0

        if initialSOC < 0 || initialSOC > 100 {
            errorMessage = "Initial SOC must be between 0 and 100."
            throw CarManagementError.validationFailed
        }

        if purchasePrice < 0 {
            errorMessage = "Purchase price cannot be negative."
            throw CarManagementError.validationFailed
        }

        if isPrimary {
            for car in existingCars where car.id != editingCar?.id {
                car.isPrimary = false
            }
        }

        let savedCar: Car
        if let editingCar {
            savedCar = editingCar
            savedCar.carName = resolvedName
            savedCar.make = resolvedMake
            savedCar.modelName = resolvedModel
            savedCar.variant = resolvedVariant
            savedCar.batterySizeKWh = battery
            savedCar.initialOdometerKM = initialOdometer
            savedCar.initialSOCPercent = initialSOC
            savedCar.collectionDate = normalizedCollectionDate
            savedCar.licensePlate = licensePlateText.trimmingCharacters(in: .whitespacesAndNewlines)
            savedCar.purchasePriceSGD = purchasePrice
            savedCar.isPrimary = isPrimary
            savedCar.updatedAt = .now
        } else {
            savedCar = Car(
                carName: resolvedName,
                make: resolvedMake,
                modelName: resolvedModel,
                variant: resolvedVariant,
                batterySizeKWh: battery,
                initialOdometerKM: initialOdometer,
                initialSOCPercent: initialSOC,
                collectionDate: normalizedCollectionDate,
                licensePlate: licensePlateText.trimmingCharacters(in: .whitespacesAndNewlines),
                purchasePriceSGD: purchasePrice,
                isPrimary: isPrimary || existingCars.isEmpty
            )
            modelContext.insert(savedCar)
        }

        try persistPhoto(for: savedCar)
        try modelContext.save()
        resetForm()
    }

    func delete(_ car: Car, using modelContext: ModelContext) throws {
        if !car.imageFileID.isEmpty {
            ImageStorageManager.deleteImage(id: car.imageFileID)
        }
        modelContext.delete(car)
        try modelContext.save()
        if editingCar?.id == car.id {
            resetForm()
        }
    }

    func setPrimary(_ car: Car, allCars: [Car], using modelContext: ModelContext) throws {
        for item in allCars {
            item.isPrimary = item.id == car.id
            item.updatedAt = .now
        }
        try modelContext.save()
    }

    private func persistPhoto(for car: Car) throws {
        if let data = pendingPhotoData {
            if !car.imageFileID.isEmpty {
                ImageStorageManager.deleteImage(id: car.imageFileID)
            }
            car.imageFileID = try ImageStorageManager.saveCarPhoto(data, carID: car.id)
            return
        }

        if removeExistingPhoto, !car.imageFileID.isEmpty {
            ImageStorageManager.deleteImage(id: car.imageFileID)
            car.imageFileID = ""
        }
    }

    private var resolvedBrand: String {
        if brandSelection == CarBrandCatalog.other {
            return customBrandText
        }
        return brandSelection
    }

    private var resolvedModelName: String {
        if showsModelCatalog {
            if modelSelection == CarModelCatalog.other {
                return customModelText
            }
            return modelSelection
        }
        return customModelText.isEmpty ? modelName : customModelText
    }

    private var resolvedVariantName: String {
        if showsVariantCatalog {
            if variantSelection == CarVariantCatalog.other {
                return customVariantText
            }
            return variantSelection
        }
        return customVariantText.isEmpty ? variant : customVariantText
    }

    private var suggestedCarName: String? {
        let brand = resolvedBrand.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = resolvedModelName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !brand.isEmpty, !model.isEmpty else { return nil }
        return "\(brand) \(model)"
    }

    private var normalizedCollectionDate: Date {
        Calendar.current.startOfDay(for: collectionDate)
    }

    private func clearVariantFields() {
        variantSelection = ""
        customVariantText = ""
    }

    private func syncVariantFields(from variantValue: String, brand: String, model: String) {
        variant = variantValue
        guard CarVariantCatalog.hasCatalogVariants(for: brand, model: model) else {
            variantSelection = ""
            customVariantText = variantValue
            return
        }

        if CarVariantCatalog.variants(for: brand, model: model).contains(variantValue) {
            variantSelection = variantValue
            customVariantText = ""
        } else if variantValue.isEmpty {
            variantSelection = ""
            customVariantText = ""
        } else {
            variantSelection = CarVariantCatalog.other
            customVariantText = variantValue
        }
    }

    private func syncModelFields(from model: String, brand: String) {
        modelName = model
        guard CarModelCatalog.hasCatalogModels(for: brand) else {
            modelSelection = ""
            customModelText = model
            return
        }

        if CarModelCatalog.models(for: brand).contains(model) {
            modelSelection = model
            customModelText = ""
        } else if model.isEmpty {
            modelSelection = ""
            customModelText = ""
        } else {
            modelSelection = CarModelCatalog.other
            customModelText = model
        }
    }

    private func syncBrandFields(from make: String) {
        if CarBrandCatalog.commonBrands.contains(make) {
            brandSelection = make
            customBrandText = ""
        } else if make.isEmpty {
            brandSelection = ""
            customBrandText = ""
        } else {
            brandSelection = CarBrandCatalog.other
            customBrandText = make
        }
    }
}

enum CarManagementError: LocalizedError {
    case validationFailed

    var errorDescription: String? {
        "Please complete the required car fields."
    }
}
