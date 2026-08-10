import XCTest
@testable import EVAi2

final class PDFReceiptImportServiceTests: XCTestCase {
    func testDetectsPDFData() {
        XCTAssertTrue(PDFReceiptImportService.isPDF(Data("%PDF-1.4".utf8)))
        XCTAssertFalse(PDFReceiptImportService.isPDF(Data([0xFF, 0xD8, 0xFF])))
    }

    func testRendersPagesFromPDF() throws {
        let pdfData = try makeSamplePDF(withText: "Receipt Total 16.20 SGD")
        let pages = try PDFReceiptImportService.renderPages(from: pdfData, maxPages: 2)

        XCTAssertEqual(pages.count, 1)
        XCTAssertFalse(pages[0].isEmpty)
        XCTAssertNotNil(ImageProcessor.makeThumbnail(from: pages[0]))
    }

    private func makeSamplePDF(withText text: String) throws -> Data {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else {
            throw PDFReceiptImportError.invalidPDF
        }

        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw PDFReceiptImportError.invalidPDF
        }

        context.beginPDFPage(nil)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18)
        ]
        text.draw(at: CGPoint(x: 72, y: 700), withAttributes: attributes)
        context.endPDFPage()
        context.closePDF()

        return data as Data
    }
}
