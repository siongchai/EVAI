import Foundation
import Observation
import SwiftData
import SwiftUI
import UIKit

enum CapturePhase: Equatable {
    case capture
    case processing
    case review
    case viewingSources
}

enum ProcessingStepID: String, CaseIterable, Identifiable {
    case classifyingImages
    case preparingImages
    case aiExtraction
    case parsingJSON
    case validatingResults

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classifyingImages: "Reviewing Images"
        case .preparingImages: "Preparing Images"
        case .aiExtraction: "AI Extraction"
        case .parsingJSON: "Parsing JSON"
        case .validatingResults: "Validating Results"
        }
    }
}

enum ProcessingStepStatus: Equatable {
    case pending
    case inProgress
    case completed
}

struct ProcessingStepState: Identifiable, Equatable {
    let id: ProcessingStepID
    var status: ProcessingStepStatus
    var detail: String

    var progressLabel: String {
        switch status {
        case .pending: detail
        case .inProgress: detail
        case .completed: detail
        }
    }
}

@Observable
@MainActor
final class CaptureViewModel {
    var phase: CapturePhase = .capture
    var images: [CaptureImageItem] = []
    var isShowingCamera = false
    var isDropTargeted = false
    var errorMessage: String?
    var showError = false

    var sessionDraft = EditableSessionDraft()
    var rawAIResponse = ""
    var validationMessages: [String] = []
    var extractionWarnings: [String] = []
    var fieldMetadata: [ExtractionFieldKey: ExtractionFieldMetadata] = [:]
    var showFieldSources = true
    var extractionEngineName = ""
    var didSaveSession = false
    var processingSteps: [ProcessingStepState] = ProcessingStepID.allCases.map {
        ProcessingStepState(id: $0, status: .pending, detail: "")
    }

    var canAnalyze: Bool {
        images.count >= ImageProcessor.minCaptureImages && !isProcessing
    }

    var imagesNeededForAnalysis: Int {
        max(0, ImageProcessor.minCaptureImages - images.count)
    }

    var isProcessing = false
    var confidenceLabel: String {
        let value = sessionDraft.extractionConfidence
        if value >= 0.9 { return "High Confidence" }
        if value >= 0.75 { return "Medium Confidence" }
        return "Review Recommended"
    }

    func importImageData(_ dataItems: [Data]) {
        guard !dataItems.isEmpty else { return }

        for data in dataItems {
            guard images.count < ImageProcessor.maxCaptureImages else {
                presentError("You can analyze up to \(ImageProcessor.maxCaptureImages) session files.")
                break
            }

            do {
                if PDFReceiptImportService.isPDF(data) {
                    try importPDFReceipt(from: data)
                } else {
                    try addImage(from: data)
                }
            } catch {
                presentError(error.localizedDescription)
            }
        }
    }

    func importPDFReceipt(from url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            try importPDFReceipt(from: data)
        } catch {
            presentError(error.localizedDescription)
        }
    }

    func importPDFReceipt(from data: Data) throws {
        let remainingSlots = ImageProcessor.maxCaptureImages - images.count
        guard remainingSlots > 0 else {
            presentError("You can analyze up to \(ImageProcessor.maxCaptureImages) session files.")
            return
        }

        let pages = try PDFReceiptImportService.renderPages(from: data, maxPages: remainingSlots)
        for pageData in pages {
            guard images.count < ImageProcessor.maxCaptureImages else { break }
            try addImage(from: pageData, category: .receipt)
        }
    }

    func capturePhoto(_ image: UIImage) {
        guard images.count < ImageProcessor.maxCaptureImages else {
            presentError("You can analyze up to \(ImageProcessor.maxCaptureImages) images per session.")
            return
        }

        do {
            let data = try ImageProcessor.jpegData(from: image, quality: 0.85)
            try addImage(from: data)
        } catch {
            presentError(error.localizedDescription)
        }
    }

    func importDroppedImages(_ dataItems: [Data]) {
        for data in dataItems {
            guard images.count < ImageProcessor.maxCaptureImages else {
                presentError("You can analyze up to \(ImageProcessor.maxCaptureImages) images per session.")
                break
            }

            do {
                try addImage(from: data)
            } catch {
                presentError(error.localizedDescription)
            }
        }
    }

    func addImage(from data: Data, category: CaptureImageCategory = .sessionPhoto) throws {
        let item = try ImageProcessor.buildCaptureItem(from: data, category: category)
        images.append(item)
        ImageCacheService.shared.storeThumbnail(item.thumbnail, for: item.id.uuidString)
    }

    func removeImage(_ item: CaptureImageItem) {
        images.removeAll { $0.id == item.id }
    }

    func analyzeSession(using modelContext: ModelContext) async {
        guard images.count >= ImageProcessor.minCaptureImages else {
            presentError("Upload at least \(ImageProcessor.minCaptureImages) session photos to analyze.")
            return
        }

        phase = .processing
        isProcessing = true
        resetProcessingSteps()
        errorMessage = nil

        do {
            try persistImagesForProcessing()

            updateStep(.classifyingImages, status: .inProgress, detail: "0/\(images.count)")
            updateStep(.classifyingImages, status: .completed, detail: "\(images.count)/\(images.count)")

            updateStep(.preparingImages, status: .inProgress, detail: "0/\(images.count)")
            updateStep(.preparingImages, status: .completed, detail: "\(images.count)/\(images.count)")

            updateStep(.aiExtraction, status: .inProgress, detail: AIExtractionService.preferredEngine.displayName)

            let output: SessionExtractionOutput
            do {
                output = try await AIExtractionService.extractSession(from: images)
            } catch {
                if shouldQueueForRetry(error: error) {
                    try ExtractionQueueService.enqueue(
                        images: images,
                        error: error.localizedDescription,
                        modelContext: modelContext
                    )
                    presentError("Extraction queued for retry when you're back online.")
                    phase = .capture
                    isProcessing = false
                    return
                }
                throw error
            }

            rawAIResponse = output.rawResponse
            fieldMetadata = output.fieldMetadata
            extractionWarnings = output.warnings
            extractionEngineName = output.engineName
            updateStep(.aiExtraction, status: .completed, detail: "Complete")

            updateStep(.parsingJSON, status: .inProgress, detail: "Parsing…")
            sessionDraft = EditableSessionDraft(from: output.data)
            sessionDraft.extractionConfidence = output.overallConfidence
            applyDefaultCarModel(using: modelContext)
            updateStep(.parsingJSON, status: .completed, detail: "Complete")

            updateStep(.validatingResults, status: .inProgress, detail: "Validating…")
            let validation = ExtractionValidator.validateSession(output.data)
            validationMessages = validation.errors + validation.warnings + extractionWarnings
            updateStep(.validatingResults, status: .completed, detail: "Complete")

            if !AccessibilitySupport.isReduceMotionEnabled {
                try await Task.sleep(for: .milliseconds(400))
            }
            releaseHeavyImagePayloads()
            phase = .review
        } catch {
            ErrorLogger.log("Analyze session failed", category: .extraction, error: error)
            presentError(error.localizedDescription)
            phase = .capture
        }

        isProcessing = false
    }

    func handleMemoryWarning() {
        ImageCacheService.shared.handleMemoryWarning()
        releaseHeavyImagePayloads()
    }

    private func releaseHeavyImagePayloads() {
        for index in images.indices {
            guard images[index].storageFileID != nil else { continue }
            images[index] = CaptureImageItem(
                id: images[index].id,
                category: images[index].category,
                imageData: Data(),
                thumbnail: images[index].thumbnail,
                storageFileID: images[index].storageFileID,
                originalData: nil
            )
        }
    }

    func parseResponse(_ raw: String) throws -> ExtractedSessionData {
        try SessionExtractionParser.parseJSON(from: raw)
    }

    func validateFields() -> [String] {
        let extracted = draftAsExtractedData()
        let validation = ExtractionValidator.validateSession(extracted)
        return validation.errors + validation.warnings
    }

    func metadata(for field: ExtractionFieldKey) -> ExtractionFieldMetadata? {
        fieldMetadata[field]
    }

    func binding<T>(_ keyPath: WritableKeyPath<EditableSessionDraft, T>) -> Binding<T> {
        Binding(
            get: { self.sessionDraft[keyPath: keyPath] },
            set: { newValue in
                var draft = self.sessionDraft
                draft[keyPath: keyPath] = newValue
                self.sessionDraft = draft
            }
        )
    }

    func isFieldUncertain(_ field: ExtractionFieldKey) -> Bool {
        fieldMetadata[field]?.isUncertain == true
    }

    private func draftAsExtractedData() -> ExtractedSessionData {
        ExtractedSessionData(
            chargingLocation: sessionDraft.chargingLocation.nilIfEmpty,
            chargerId: sessionDraft.chargerId.nilIfEmpty,
            chargingNetwork: sessionDraft.chargingNetwork.nilIfEmpty,
            chargerType: sessionDraft.chargerType.nilIfEmpty,
            chargerPowerKW: Double(sessionDraft.chargerPowerKW),
            startDate: nil,
            startTime: nil,
            endDate: nil,
            endTime: nil,
            startSOCPercent: Double(sessionDraft.startSOCPercent),
            endSOCPercent: Double(sessionDraft.endSOCPercent),
            odometerKM: Double(sessionDraft.odometerKM),
            energyKWh: Double(sessionDraft.energyKWh),
            amountSGD: Double(sessionDraft.amountSGD),
            sessionDuration: sessionDraft.sessionDurationMinutes.nilIfEmpty,
            idleDuration: sessionDraft.idleDurationMinutes.nilIfEmpty,
            carModel: sessionDraft.carModel.nilIfEmpty,
            extractionConfidence: sessionDraft.extractionConfidence
        )
    }

    func saveSession(using modelContext: ModelContext) throws {
        applyDefaultCarModel(using: modelContext)
        validationMessages = validateFields()
        guard sessionDraft.chargingLocation.trimmingCharacters(in: .whitespaces).isEmpty == false else {
            throw CaptureSaveError.missingLocation
        }

        prepareImagesForSave()

        let imageIDs: String
        if images.allSatisfy({ item in
            guard let id = item.storageFileID else { return false }
            return ImageStorageManager.loadCompressed(id: id) != nil
        }), !images.isEmpty {
            imageIDs = images.map { $0.storageFileID ?? $0.id.uuidString }.joined(separator: ",")
        } else {
            let storedReferences = try ImageStorageManager.saveSessionImages(images)
            imageIDs = storedReferences.map(\.id).joined(separator: ",")
        }

        guard let session = sessionDraft.toChargingSession(
            rawAIResponse: rawAIResponse,
            sourceImageIDs: imageIDs
        ) else {
            throw CaptureSaveError.invalidDraft
        }

        modelContext.insert(session)
        try modelContext.save()

        let allSessions = (try? modelContext.fetch(FetchDescriptor<ChargingSession>())) ?? []
        WidgetDataStore.sync(from: allSessions)
        AnalyticsCacheService.save(
            AnalyticsCacheService.rebuildSummary(from: allSessions, month: .now.startOfMonth)
        )
        BackgroundTaskManager.scheduleProcessingTask()
        didSaveSession = true
    }

    func acknowledgeSavedSession() {
        didSaveSession = false
        resetCaptureFlow()
    }

    private func prepareImagesForSave() {
        var updated: [CaptureImageItem] = []
        for var item in images {
            if item.imageData.isEmpty, let id = item.storageFileID,
               let data = ImageStorageManager.loadCompressed(id: id) {
                item.imageData = data
            }
            if (item.originalData ?? Data()).isEmpty, let id = item.storageFileID,
               let data = ImageStorageManager.loadOriginal(id: id) {
                item.originalData = data
            }
            updated.append(item)
        }
        images = updated
    }

    private func persistImagesForProcessing() throws {
        var updated: [CaptureImageItem] = []
        for var item in images {
            if item.storageFileID == nil {
                let references = try ImageStorageManager.saveSessionImages([item])
                item.storageFileID = references.first?.id
            }
            if let id = item.storageFileID, item.imageData.isEmpty,
               let data = ImageStorageManager.loadCompressed(id: id) {
                item.imageData = data
            }
            updated.append(item)
        }
        images = updated
    }

    private func shouldQueueForRetry(error: Error) -> Bool {
        guard !NetworkMonitor.shared.isConnected else { return false }
        if let openAIError = error as? OpenAIServiceError {
            switch openAIError {
            case .networkFailure, .timeout, .rateLimited:
                return true
            default:
                return SecureKeyManager.hasAnyCloudKey
            }
        }
        if let claudeError = error as? ClaudeServiceError {
            switch claudeError {
            case .networkFailure, .timeout, .rateLimited:
                return true
            default:
                return SecureKeyManager.hasAnyCloudKey
            }
        }
        return SecureKeyManager.hasAnyCloudKey
    }

    func retakeImages() {
        resetCaptureFlow()
    }

    func showSourceImages() {
        phase = .viewingSources
    }

    func dismissSourceImages() {
        phase = .review
    }

    private func resetCaptureFlow() {
        phase = .capture
        images = []
        sessionDraft = EditableSessionDraft()
        rawAIResponse = ""
        validationMessages = []
        extractionWarnings = []
        fieldMetadata = [:]
        extractionEngineName = ""
        didSaveSession = false
        resetProcessingSteps()
    }

    private func resetProcessingSteps() {
        processingSteps = ProcessingStepID.allCases.map {
            ProcessingStepState(id: $0, status: .pending, detail: "")
        }
    }

    private func updateStep(_ id: ProcessingStepID, status: ProcessingStepStatus, detail: String) {
        guard let index = processingSteps.firstIndex(where: { $0.id == id }) else { return }
        processingSteps[index].status = status
        processingSteps[index].detail = detail
    }

    private func applyDefaultCarModel(using modelContext: ModelContext) {
        guard sessionDraft.carModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let defaultName = CarLookup.primaryCarDisplayName(in: modelContext) else {
            return
        }
        sessionDraft.carModel = defaultName
    }

    private func presentError(_ message: String) {
        errorMessage = message
        showError = true
    }
}

enum CaptureSaveError: LocalizedError {
    case missingLocation
    case invalidDraft

    var errorDescription: String? {
        switch self {
        case .missingLocation:
            "Charging location is required before saving."
        case .invalidDraft:
            "Unable to create a charging session from the current data."
        }
    }
}
