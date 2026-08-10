import Foundation
import ImageIO
import UIKit

enum ImageProcessorError: LocalizedError {
    case invalidImage
    case imageTooLarge(maxBytes: Int)
    case compressionFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            "The selected image could not be processed."
        case .imageTooLarge(let maxBytes):
            "Image exceeds the maximum size of \(maxBytes / 1_000_000) MB."
        case .compressionFailed:
            "Failed to compress the image."
        }
    }
}

enum ImageProcessor {
    static let maxFileSizeBytes = 3_000_000
    static let maxDimension: CGFloat = 1280
    static let ocrMaxDimension: CGFloat = 2048
    static let thumbnailMaxDimension: CGFloat = 240
    static let portraitMaxDimension: CGFloat = 512
    static let portraitMaxFileSizeBytes = 800_000
    static let jpegCompressionQuality: CGFloat = 0.78
    static let maxCaptureImages = 5
    static let minCaptureImages = 3

    /// Higher-fidelity settings for the cloud vision API so small dashboard
    /// digits and receipt line items survive compression. OpenAI accepts up to
    /// 20 MB per image and tiles at 512px, so we keep more resolution/quality
    /// here than for on-device storage.
    static let visionMaxDimension: CGFloat = 2048
    static let visionJpegQuality: CGFloat = 0.92
    static let visionMaxFileSizeBytes = 18_000_000

    static func validateImageSize(_ data: Data) throws {
        guard data.count <= maxFileSizeBytes else {
            throw ImageProcessorError.imageTooLarge(maxBytes: maxFileSizeBytes)
        }
    }

    static func downsampledCGImage(from data: Data, maxDimension: CGFloat) -> CGImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]

        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    static func downsample(data: Data, maxDimension: CGFloat) -> UIImage? {
        guard let cgImage = downsampledCGImage(from: data, maxDimension: maxDimension) else {
            return nil
        }
        return renderOpaque(UIImage(cgImage: cgImage))
    }

    static func jpegData(from image: UIImage, quality: CGFloat = jpegCompressionQuality) throws -> Data {
        let opaqueImage = renderOpaque(image)
        guard let data = opaqueImage.jpegData(compressionQuality: quality) else {
            throw ImageProcessorError.compressionFailed
        }
        return data
    }

    static func compressImage(_ image: UIImage, quality: CGFloat = jpegCompressionQuality) throws -> Data {
        try jpegData(from: image, quality: quality)
    }

    static func optimizeForPortrait(_ data: Data) throws -> Data {
        guard let image = downsample(data: data, maxDimension: portraitMaxDimension) else {
            throw ImageProcessorError.invalidImage
        }

        var quality: CGFloat = 0.82
        var compressed = try compressImage(image, quality: quality)
        while compressed.count > portraitMaxFileSizeBytes, quality > 0.55 {
            quality -= 0.1
            compressed = try compressImage(image, quality: quality)
        }
        return compressed
    }

    static func optimizeForAnalysis(_ data: Data) throws -> Data {
        guard let image = downsample(data: data, maxDimension: maxDimension) else {
            throw ImageProcessorError.invalidImage
        }

        var compressed = try compressImage(image)
        if compressed.count > maxFileSizeBytes {
            compressed = try compressImage(image, quality: 0.65)
        }
        try validateImageSize(compressed)
        return compressed
    }

    static func optimizeForOpenAI(_ data: Data) throws -> Data {
        guard let image = downsample(data: data, maxDimension: visionMaxDimension) else {
            throw ImageProcessorError.invalidImage
        }

        var quality = visionJpegQuality
        var compressed = try compressImage(image, quality: quality)
        while compressed.count > visionMaxFileSizeBytes, quality > 0.5 {
            quality -= 0.1
            compressed = try compressImage(image, quality: quality)
        }

        guard compressed.count <= visionMaxFileSizeBytes else {
            throw ImageProcessorError.imageTooLarge(maxBytes: visionMaxFileSizeBytes)
        }
        return compressed
    }

    static func convertToBase64(_ data: Data) -> String {
        data.base64EncodedString()
    }

    static func makeThumbnail(from data: Data) -> UIImage? {
        downsample(data: data, maxDimension: thumbnailMaxDimension)
    }

    static func buildCaptureItem(
        from data: Data,
        category: CaptureImageCategory = .sessionPhoto
    ) throws -> CaptureImageItem {
        let optimized = try optimizeForAnalysis(data)
        guard let thumbnail = makeThumbnail(from: optimized) else {
            throw ImageProcessorError.invalidImage
        }
        return CaptureImageItem(
            category: category,
            imageData: optimized,
            thumbnail: thumbnail,
            originalData: nil
        )
    }

    static func fixOrientation(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return renderOpaque(image) }

        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    static func renderOpaque(_ image: UIImage) -> UIImage {
        guard image.cgImage?.alphaInfo != .none,
              image.cgImage?.alphaInfo != .noneSkipFirst,
              image.cgImage?.alphaInfo != .noneSkipLast else {
            return image
        }

        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: image.size))
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
}
