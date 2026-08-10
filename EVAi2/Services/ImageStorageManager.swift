import Foundation
import UIKit
import SwiftData

struct StoredImageReference: Codable, Equatable, Hashable {
    let id: String
    let category: String
    let createdAt: Date
}

enum ImageStorageError: LocalizedError {
    case diskFull
    case writeFailed
    case readFailed
    case invalidImage
    case insufficientSpace

    var errorDescription: String? {
        switch self {
        case .diskFull: "Device storage is full. Free space to save images."
        case .writeFailed: "Failed to save image to local storage."
        case .readFailed: "Failed to read stored image."
        case .invalidImage: "Image file is corrupted or unreadable."
        case .insufficientSpace: "Not enough free disk space for image storage."
        }
    }
}

enum ImageStorageManager {
    private static let rootFolder = "EVAiImages"
    private static let originalsFolder = "originals"
    private static let compressedFolder = "compressed"
    private static let thumbnailsFolder = "thumbnails"
    private static let maxStorageBytes: Int64 = 500_000_000
    private static let minimumFreeBytes: Int64 = 50_000_000

    static func prepareStorageIfNeeded() {
        for folder in [originalsFolder, compressedFolder, thumbnailsFolder] {
            let url = directoryURL(for: folder)
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    static func storedImageExists(id: String) -> Bool {
        guard !id.isEmpty else { return false }
        return FileManager.default.fileExists(atPath: fileURL(folder: compressedFolder, id: id).path)
            || FileManager.default.fileExists(atPath: fileURL(folder: originalsFolder, id: id).path)
            || FileManager.default.fileExists(atPath: fileURL(folder: thumbnailsFolder, id: id).path)
    }

    static func saveSessionImages(_ items: [CaptureImageItem]) throws -> [StoredImageReference] {
        try ensureStorageCapacity(forAdditionalBytes: Int64(items.count * 500_000))
        return try items.map { item in
            let id = item.storageFileID ?? item.id.uuidString
            try write(data: item.originalData ?? item.imageData, folder: originalsFolder, id: id)
            try write(data: item.imageData, folder: compressedFolder, id: id)
            if let thumbData = try? ImageProcessor.jpegData(from: item.thumbnail, quality: 0.7) {
                try write(data: thumbData, folder: thumbnailsFolder, id: id)
            }
            return StoredImageReference(id: id, category: item.category.rawValue, createdAt: .now)
        }
    }

    static func saveCarPhoto(_ data: Data, carID: UUID) throws -> String {
        try savePortraitPhoto(data, fileID: "car-\(carID.uuidString)")
    }

    static func saveProfilePhoto(_ data: Data, profileID: UUID) throws -> String {
        try savePortraitPhoto(data, fileID: "profile-\(profileID.uuidString)")
    }

    private static func savePortraitPhoto(_ data: Data, fileID: String) throws -> String {
        let compressed = try ImageProcessor.optimizeForPortrait(data)
        try ensureStorageCapacity(forAdditionalBytes: Int64(compressed.count))
        guard let thumbnail = ImageProcessor.makeThumbnail(from: compressed) else {
            throw ImageStorageError.invalidImage
        }

        try writePortrait(data: compressed, folder: compressedFolder, id: fileID)
        if let thumbData = try? ImageProcessor.jpegData(from: thumbnail, quality: 0.7) {
            try writePortrait(data: thumbData, folder: thumbnailsFolder, id: fileID)
        }
        ImageCacheService.shared.storeThumbnail(thumbnail, for: fileID)
        return fileID
    }

    static func loadDisplayImage(id: String, maxPixelSize: CGFloat = ImageProcessor.thumbnailMaxDimension) -> UIImage? {
        guard storedImageExists(id: id) else { return nil }
        if let cached = ImageCacheService.shared.cachedImage(for: id) {
            return cached
        }
        if let data = read(folder: thumbnailsFolder, id: id),
           let image = ImageProcessor.downsample(data: data, maxDimension: maxPixelSize) {
            ImageCacheService.shared.storeThumbnail(image, for: id)
            return image
        }
        if let data = read(folder: compressedFolder, id: id),
           let image = ImageProcessor.downsample(data: data, maxDimension: maxPixelSize) {
            ImageCacheService.shared.storeThumbnail(image, for: id)
            return image
        }
        return nil
    }

    static func loadCompressed(id: String) -> Data? {
        read(folder: compressedFolder, id: id)
    }

    static func loadOriginal(id: String) -> Data? {
        read(folder: originalsFolder, id: id)
    }

    static func loadThumbnail(id: String) -> UIImage? {
        guard let data = read(folder: thumbnailsFolder, id: id) else { return nil }
        return UIImage(data: data)
    }

    static func deleteImage(id: String) {
        for folder in [originalsFolder, compressedFolder, thumbnailsFolder] {
            let url = fileURL(folder: folder, id: id)
            try? FileManager.default.removeItem(at: url)
        }
        ImageCacheService.shared.removeThumbnail(for: id)
    }

    static func deleteOrphans(validIDs: Set<String>) {
        for folder in [originalsFolder, compressedFolder, thumbnailsFolder] {
            guard let urls = try? FileManager.default.contentsOfDirectory(
                at: directoryURL(for: folder),
                includingPropertiesForKeys: nil
            ) else { continue }
            for url in urls {
                let id = url.deletingPathExtension().lastPathComponent
                if !validIDs.contains(id) {
                    try? FileManager.default.removeItem(at: url)
                }
            }
        }
    }

    static func clearCache() {
        for folder in [compressedFolder, thumbnailsFolder] {
            guard let urls = try? FileManager.default.contentsOfDirectory(
                at: directoryURL(for: folder),
                includingPropertiesForKeys: nil
            ) else { continue }
            for url in urls {
                try? FileManager.default.removeItem(at: url)
            }
        }
        ImageCacheService.shared.clearAll()
    }

    static func totalDiskUsage() -> Int64 {
        var total: Int64 = 0
        for folder in [originalsFolder, compressedFolder, thumbnailsFolder] {
            guard let urls = try? FileManager.default.contentsOfDirectory(
                at: directoryURL(for: folder),
                includingPropertiesForKeys: [.fileSizeKey]
            ) else { continue }
            for url in urls {
                if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    total += Int64(size)
                }
            }
        }
        return total
    }

    static func formattedDiskUsage() -> String {
        ByteCountFormatter.string(fromByteCount: totalDiskUsage(), countStyle: .file)
    }

    static func compressStoredImages() {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directoryURL(for: originalsFolder),
            includingPropertiesForKeys: nil
        ) else { return }

        for url in urls {
            guard let data = try? Data(contentsOf: url),
                  let compressed = try? ImageProcessor.optimizeForAnalysis(data) else { continue }
            let id = url.deletingPathExtension().lastPathComponent
            try? write(data: compressed, folder: compressedFolder, id: id)
            if let thumb = ImageProcessor.makeThumbnail(from: compressed),
               let thumbData = try? ImageProcessor.jpegData(from: thumb, quality: 0.7) {
                try? write(data: thumbData, folder: thumbnailsFolder, id: id)
            }
        }
    }

    static func allStoredImageIDs() -> Set<String> {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directoryURL(for: compressedFolder),
            includingPropertiesForKeys: nil
        ) else { return [] }
        return Set(urls.map { $0.deletingPathExtension().lastPathComponent })
    }

    static func protectedImageIDs(from context: ModelContext) -> Set<String> {
        var ids = Set<String>()

        let sessions = (try? context.fetch(FetchDescriptor<ChargingSession>())) ?? []
        for session in sessions {
            ids.formUnion(session.sourceImageIDList)
        }

        let profiles = (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []
        for profile in profiles where !profile.imageFileID.isEmpty {
            ids.insert(profile.imageFileID)
        }

        let cars = (try? context.fetch(FetchDescriptor<Car>())) ?? []
        for car in cars where !car.imageFileID.isEmpty {
            ids.insert(car.imageFileID)
        }

        return ids
    }

    private static func ensureStorageCapacity(forAdditionalBytes bytes: Int64) throws {
        let usage = totalDiskUsage()
        if usage + bytes > maxStorageBytes {
            throw ImageStorageError.insufficientSpace
        }
        if let free = freeDiskSpace(), free < minimumFreeBytes + bytes {
            throw ImageStorageError.diskFull
        }
    }

    private static func freeDiskSpace() -> Int64? {
        guard let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path,
              let attrs = try? FileManager.default.attributesOfFileSystem(forPath: path),
              let free = attrs[.systemFreeSize] as? Int64 else {
            return nil
        }
        return free
    }

    private static func writePortrait(data: Data, folder: String, id: String) throws {
        let url = fileURL(folder: folder, id: id)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            ErrorLogger.log("Portrait image write failed", category: .storage, error: error)
            throw ImageStorageError.writeFailed
        }
    }

    private static func write(data: Data, folder: String, id: String) throws {
        let url = fileURL(folder: folder, id: id)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        do {
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            ErrorLogger.log("Image write failed", category: .storage, error: error)
            throw ImageStorageError.writeFailed
        }
    }

    private static func read(folder: String, id: String) -> Data? {
        let url = fileURL(folder: folder, id: id)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            return try Data(contentsOf: url)
        } catch {
            ErrorLogger.log("Image read failed for \(id)", category: .storage, error: error)
            return nil
        }
    }

    private static func fileURL(folder: String, id: String) -> URL {
        directoryURL(for: folder).appendingPathComponent("\(id).jpg")
    }

    private static func directoryURL(for folder: String) -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(rootFolder, isDirectory: true)
            .appendingPathComponent(folder, isDirectory: true)
    }
}
