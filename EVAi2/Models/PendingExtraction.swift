import Foundation
import SwiftData
import UIKit

enum PendingExtractionStatus: String, Codable {
    case pending
    case processing
    case failed
    case completed
}

@Model
final class PendingExtraction {
    var id: UUID = Foundation.UUID()
    var imageIDs: String = ""
    var categoriesJSON: String = ""
    var createdAt: Date = Foundation.Date.now
    var retryCount: Int = 0
    var lastError: String = ""
    var statusRaw: String = PendingExtractionStatus.pending.rawValue

    init(
        id: UUID = UUID(),
        imageIDs: String,
        categoriesJSON: String,
        createdAt: Date = .now,
        retryCount: Int = 0,
        lastError: String = "",
        status: PendingExtractionStatus = .pending
    ) {
        self.id = id
        self.imageIDs = imageIDs
        self.categoriesJSON = categoriesJSON
        self.createdAt = createdAt
        self.retryCount = retryCount
        self.lastError = lastError
        self.statusRaw = status.rawValue
    }

    var status: PendingExtractionStatus {
        get { PendingExtractionStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
}

enum ExtractionQueueService {
    static let maxRetries = 5

    static func enqueue(images: [CaptureImageItem], error: String, modelContext: ModelContext) throws {
        let ids = images.compactMap { $0.storageFileID ?? $0.id.uuidString }.joined(separator: ",")
        let categories = images.map { ["id": $0.storageFileID ?? $0.id.uuidString, "category": $0.category.rawValue] }
        let categoriesData = try JSONSerialization.data(withJSONObject: categories)
        let categoriesJSON = String(data: categoriesData, encoding: .utf8) ?? "[]"

        let pending = PendingExtraction(
            imageIDs: ids,
            categoriesJSON: categoriesJSON,
            lastError: error
        )
        modelContext.insert(pending)
        try modelContext.save()
        BackgroundTaskManager.scheduleProcessingTask()
    }

    static func pendingItems(from context: ModelContext) -> [PendingExtraction] {
        let pending = PendingExtractionStatus.pending.rawValue
        let failed = PendingExtractionStatus.failed.rawValue
        let descriptor = FetchDescriptor<PendingExtraction>(
            predicate: #Predicate { $0.statusRaw == pending || $0.statusRaw == failed },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func processPending(context: ModelContext) async -> Int {
        let items = pendingItems(from: context)
        guard !items.isEmpty else { return 0 }

        var processed = 0
        for item in items where item.retryCount < maxRetries {
            item.status = .processing
            try? context.save()

            guard let images = loadImages(for: item), !images.isEmpty else {
                item.status = .failed
                item.lastError = "Stored images unavailable."
                item.retryCount += 1
                try? context.save()
                continue
            }

            do {
                _ = try await AIExtractionService.extractSession(from: images)
                item.status = .completed
                processed += 1
            } catch {
                item.status = .failed
                item.retryCount += 1
                item.lastError = error.localizedDescription
                ErrorLogger.log("Queued extraction retry failed", category: .extraction, error: error)
            }
            try? context.save()
        }
        return processed
    }

    static func loadImages(for item: PendingExtraction) -> [CaptureImageItem]? {
        guard let data = item.categoriesJSON.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] else {
            return nil
        }

        var items: [CaptureImageItem] = []
        for entry in array {
            guard let id = entry["id"],
                  let categoryRaw = entry["category"],
                  let category = CaptureImageCategory(rawValue: categoryRaw),
                  let compressed = ImageStorageManager.loadCompressed(id: id) else {
                continue
            }
            let thumbnail = ImageCacheService.shared.thumbnail(for: id)
                ?? ImageProcessor.makeThumbnail(from: compressed)
                ?? UIImage()
            items.append(CaptureImageItem(
                id: UUID(uuidString: id) ?? UUID(),
                category: category,
                imageData: compressed,
                thumbnail: thumbnail,
                storageFileID: id
            ))
        }
        return items.isEmpty ? nil : items
    }

    static func purgeCompleted(context: ModelContext) {
        let completed = PendingExtractionStatus.completed.rawValue
        let descriptor = FetchDescriptor<PendingExtraction>(
            predicate: #Predicate { $0.statusRaw == completed }
        )
        if let items = try? context.fetch(descriptor) {
            for item in items {
                context.delete(item)
            }
            try? context.save()
        }
    }
}
