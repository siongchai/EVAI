import XCTest
@testable import EVAi2

final class SOCExtractionServiceTests: XCTestCase {

    func testExtractsStartEndFromTwoDashboardSections() {
        let ocr = """
        --- Image 1 ---
        17%
        120 km
        ODO 22280
        8:34 pm
        --- Image 2 ---
        100%
        410 km
        10:17 am
        --- Image 3 ---
        Total $16.20
        35.5 kWh
        """
        let pair = SOCExtractionService.extractPair(from: ocr)
        XCTAssertEqual(pair.start, 17)
        XCTAssertEqual(pair.end, 100)
        XCTAssertEqual(pair.readings.count, 2)
    }

    func testReconcileUsesTwoDashboardReadingsOverAI() {
        let ocr = """
        --- Image 1 ---
        17%
        30
        --- Image 2 ---
        100%
        30
        """
        let result = SOCExtractionService.reconcile(start: 30, end: 30, ocrText: ocr)
        XCTAssertEqual(result.start, 17)
        XCTAssertEqual(result.end, 100)
        XCTAssertTrue(result.notes.contains(where: { $0.contains("overridden") }))
    }

    func testReconcileRejectsCruiseSpeedWhenOCREmpty() {
        let ocr = """
        --- Image 1 ---
        some text
        """
        let result = SOCExtractionService.reconcile(start: 30, end: 30, ocrText: ocr)
        // 30 is cruise speed and OCR has nothing — both should be rejected
        XCTAssertNil(result.start)
        XCTAssertNil(result.end)
    }

    func testReconcileKeepsValidAIWhenOCRHasNothing() {
        let ocr = ""
        let result = SOCExtractionService.reconcile(start: 17, end: 85, ocrText: ocr)
        XCTAssertEqual(result.start, 17)
        XCTAssertEqual(result.end, 85)
    }

    func testReconcileSwapsIfStartGreaterThanEnd() {
        let ocr = ""
        let result = SOCExtractionService.reconcile(start: 90, end: 20, ocrText: ocr)
        XCTAssertEqual(result.start, 20)
        XCTAssertEqual(result.end, 90)
    }

    func testIsCruiseSpeed() {
        XCTAssertTrue(SOCExtractionService.isCruiseSpeed(30))
        XCTAssertTrue(SOCExtractionService.isCruiseSpeed(80))
        XCTAssertFalse(SOCExtractionService.isCruiseSpeed(17))
        XCTAssertFalse(SOCExtractionService.isCruiseSpeed(99))
    }

    func testIsConfirmedInOCR() {
        let ocr = "--- Image 1 ---\n17%\n--- Image 2 ---\n100%"
        XCTAssertTrue(SOCExtractionService.isConfirmedInOCR(17, ocrText: ocr))
        XCTAssertTrue(SOCExtractionService.isConfirmedInOCR(100, ocrText: ocr))
        XCTAssertFalse(SOCExtractionService.isConfirmedInOCR(30, ocrText: ocr))
    }

    func testExtractPairFromSectionsWithoutPercentSymbol() {
        // Simulate OCR that reads battery level without % (common on some dashboards)
        let ocr = """
        --- Image 1 ---
        30
        17
        120 km
        ODO 22280
        --- Image 2 ---
        30
        100
        410 km
        """
        let pair = SOCExtractionService.extractPair(from: ocr)
        // 30 is cruise speed, should be excluded; 17 and 100 should be picked
        XCTAssertEqual(pair.start, 17)
        XCTAssertEqual(pair.end, 100)
    }
}
