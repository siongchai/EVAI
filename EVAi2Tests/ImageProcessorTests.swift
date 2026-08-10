import XCTest
import UIKit
@testable import EVAi2

final class ImageProcessorTests: XCTestCase {
    func testOptimizeForAnalysisReducesLargeImage() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2400, height: 1800)).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2400, height: 1800))
        }
        guard let data = image.jpegData(compressionQuality: 1.0) else {
            XCTFail("Unable to create JPEG data")
            return
        }

        let optimized = try ImageProcessor.optimizeForAnalysis(data)
        XCTAssertLessThanOrEqual(optimized.count, ImageProcessor.maxFileSizeBytes)
    }

    func testInvalidImageDataThrows() {
        XCTAssertThrowsError(try ImageProcessor.optimizeForAnalysis(Data([0x00, 0x01, 0x02]))) { error in
            XCTAssertTrue(error is ImageProcessorError)
        }
    }
}
