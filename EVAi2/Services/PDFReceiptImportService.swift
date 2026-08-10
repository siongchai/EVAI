import Foundation
import PDFKit
import UIKit

enum PDFReceiptImportError: LocalizedError {
    case invalidPDF
    case noPages

    var errorDescription: String? {
        switch self {
        case .invalidPDF: "The selected file is not a valid PDF."
        case .noPages: "The PDF does not contain any pages."
        }
    }
}

enum PDFReceiptImportService {
    static func isPDF(_ data: Data) -> Bool {
        guard data.count >= 4 else { return false }
        return data.prefix(4) == Data("%PDF".utf8)
    }

    static func renderPages(from pdfData: Data, maxPages: Int) throws -> [Data] {
        guard let document = PDFDocument(data: pdfData) else {
            throw PDFReceiptImportError.invalidPDF
        }

        let pageCount = min(max(document.pageCount, 0), max(1, maxPages))
        guard pageCount > 0 else {
            throw PDFReceiptImportError.noPages
        }

        var renderedPages: [Data] = []
        renderedPages.reserveCapacity(pageCount)

        for index in 0 ..< pageCount {
            guard let page = document.page(at: index) else { continue }
            let image = renderPage(page)
            renderedPages.append(try ImageProcessor.jpegData(from: image, quality: 0.9))
        }

        guard !renderedPages.isEmpty else {
            throw PDFReceiptImportError.noPages
        }

        return renderedPages
    }

    private static func renderPage(_ page: PDFPage) -> UIImage {
        let bounds = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)

        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            context.cgContext.saveGState()
            context.cgContext.translateBy(x: 0, y: size.height)
            context.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: context.cgContext)
            context.cgContext.restoreGState()
        }
    }
}
