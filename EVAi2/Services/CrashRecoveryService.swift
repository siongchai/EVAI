import Foundation
import SwiftData

enum CrashRecoveryService {
    static func recoverRawResponse(_ session: ChargingSession) -> String {
        guard DataProtectionService.isEncrypted(session.rawAIResponse) else {
            return session.rawAIResponse
        }
        do {
            return try DataProtectionService.decrypt(session.rawAIResponse)
        } catch {
            ErrorLogger.log("Corrupt encrypted response", category: .database, error: error)
            return ""
        }
    }

    static func safeParseAIResponse(_ raw: String) -> ExtractedSessionData? {
        guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        do {
            return try SessionExtractionParser.parseJSON(from: raw)
        } catch {
            ErrorLogger.log("Corrupt AI response", category: .extraction, error: error)
            return nil
        }
    }

    static func safeLoadImage(id: String) -> Data? {
        guard let data = ImageStorageManager.loadCompressed(id: id) else {
            ErrorLogger.log("Corrupt or missing image \(id)", category: .image)
            return nil
        }
        guard ImageProcessor.downsample(data: data, maxDimension: 32) != nil else {
            ErrorLogger.log("Corrupt image file \(id)", category: .image)
            ImageStorageManager.deleteImage(id: id)
            return nil
        }
        return data
    }

    static func handleContainerFailure(_ error: Error) -> ModelContainer? {
        ErrorLogger.log("SwiftData container failure", category: .database, error: error)
        ModelContainerFactory.deleteIncompatibleStoresForRecovery()
        return try? ModelContainerFactory.make(allowRecovery: false)
    }

    static func resumeInterruptedExtraction(context: ModelContext) async {
        let processing = PendingExtractionStatus.processing.rawValue
        let descriptor = FetchDescriptor<PendingExtraction>(
            predicate: #Predicate { $0.statusRaw == processing }
        )
        if let items = try? context.fetch(descriptor) {
            for item in items {
                item.status = .pending
            }
            try? context.save()
        }
        _ = await ExtractionQueueService.processPending(context: context)
    }
}
