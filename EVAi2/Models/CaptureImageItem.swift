import Foundation
import UIKit

struct CaptureImageItem: Identifiable, Equatable {
    let id: UUID
    var category: CaptureImageCategory
    var imageData: Data
    var thumbnail: UIImage
    var storageFileID: String?
    var originalData: Data?

    init(
        id: UUID = UUID(),
        category: CaptureImageCategory,
        imageData: Data,
        thumbnail: UIImage,
        storageFileID: String? = nil,
        originalData: Data? = nil
    ) {
        self.id = id
        self.category = category
        self.imageData = imageData
        self.thumbnail = thumbnail
        self.storageFileID = storageFileID
        self.originalData = originalData
    }

    static func == (lhs: CaptureImageItem, rhs: CaptureImageItem) -> Bool {
        lhs.id == rhs.id
    }

    /// Highest-fidelity bytes available for cloud vision and OCR.
    /// Prefers the camera/import original over the 1280px capture copy in `imageData`.
    func bestAvailableImageData() -> Data {
        if let originalData, !originalData.isEmpty {
            return originalData
        }
        return imageData
    }
}
