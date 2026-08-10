import Foundation
import UIKit

final class ImageCacheService {
    static let shared = ImageCacheService()

    private let cache = NSCache<NSString, UIImage>()
    private init() {
        cache.countLimit = 24
        cache.totalCostLimit = 12_000_000
    }

    func cachedImage(for id: String) -> UIImage? {
        cache.object(forKey: id as NSString)
    }

    func thumbnail(for id: String) -> UIImage? {
        if let cached = cachedImage(for: id) {
            return cached
        }
        return ImageStorageManager.loadDisplayImage(id: id)
    }

    func storeThumbnail(_ image: UIImage, for id: String) {
        cache.setObject(image, forKey: id as NSString, cost: memoryCost(of: image))
    }

    private func memoryCost(of image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        return cgImage.width * cgImage.height * 4
    }

    func removeThumbnail(for id: String) {
        cache.removeObject(forKey: id as NSString)
    }

    func clearAll() {
        cache.removeAllObjects()
    }

    func handleMemoryWarning() {
        cache.removeAllObjects()
    }
}
