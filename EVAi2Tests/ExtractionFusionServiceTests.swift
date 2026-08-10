import XCTest
@testable import EVAi2

final class ExtractionFusionServiceTests: XCTestCase {

    func testUsesOCRWhenAIHasCruiseSpeeds() {
        // AI returns 30/30 (cruise speed) — OCR should fill in
        let ai = ExtractedSessionData(
            startSOCPercent: 30,
            endSOCPercent: 30,
            extractionConfidence: 0.8
        )
        let ocr = HeuristicExtractionResult(
            data: ExtractedSessionData(startSOCPercent: 17, endSOCPercent: 100),
            strongFields: [.startSOCPercent, .endSOCPercent],
            socFromDashboardSections: true
        )

        let result = ExtractionFusionService.merge(ai: ai, ocr: ocr)

        XCTAssertEqual(result.data.startSOCPercent, 17)
        XCTAssertEqual(result.data.endSOCPercent, 100)
        XCTAssertEqual(result.fieldSources[.startSOCPercent], .ocr)
        XCTAssertEqual(result.fieldSources[.endSOCPercent], .ocr)
    }

    func testTrustsValidAIPairOverOCR() {
        // AI returns valid 17/100 — wins even when OCR has different (wrong) values
        let ai = ExtractedSessionData(
            startSOCPercent: 17,
            endSOCPercent: 100,
            extractionConfidence: 0.9
        )
        let ocr = HeuristicExtractionResult(
            data: ExtractedSessionData(startSOCPercent: 10, endSOCPercent: 100),
            strongFields: [.startSOCPercent, .endSOCPercent],
            socFromDashboardSections: true
        )

        let result = ExtractionFusionService.merge(ai: ai, ocr: ocr)

        XCTAssertEqual(result.data.startSOCPercent, 17)
        XCTAssertEqual(result.data.endSOCPercent, 100)
        XCTAssertEqual(result.fieldSources[.startSOCPercent], .ai)
        XCTAssertEqual(result.fieldSources[.endSOCPercent], .ai)
    }

    func testPrefersOCREnergyWhenStrongMatch() {
        let ai = ExtractedSessionData(energyKWh: 12, extractionConfidence: 0.7)
        let ocr = HeuristicExtractionResult(
            data: ExtractedSessionData(energyKWh: 35.5),
            strongFields: [.energyKWh],
            socFromDashboardSections: false
        )

        let result = ExtractionFusionService.merge(ai: ai, ocr: ocr)

        XCTAssertEqual(result.data.energyKWh, 35.5)
        XCTAssertEqual(result.fieldSources[.energyKWh], .ocr)
    }

    func testPrefersAILocationWhenBothPresent() {
        let ai = ExtractedSessionData(
            chargingLocation: "1 HarbourFront Walk, VivoCity",
            extractionConfidence: 0.9
        )
        let ocr = HeuristicExtractionResult(
            data: ExtractedSessionData(chargingLocation: "35.5 kWh delivered"),
            strongFields: [],
            socFromDashboardSections: false
        )

        let result = ExtractionFusionService.merge(ai: ai, ocr: ocr)

        XCTAssertEqual(result.data.chargingLocation, "1 HarbourFront Walk, VivoCity")
        XCTAssertEqual(result.fieldSources[.chargingLocation], .ai)
    }

    func testFillsMissingAIFieldsFromOCR() {
        let ai = ExtractedSessionData(
            chargingLocation: "VivoCity",
            extractionConfidence: 0.85
        )
        let ocr = HeuristicExtractionResult(
            data: ExtractedSessionData(
                energyKWh: 35.5,
                amountSGD: 16.20
            ),
            strongFields: [.amountSGD, .energyKWh],
            socFromDashboardSections: false
        )

        let result = ExtractionFusionService.merge(ai: ai, ocr: ocr)

        XCTAssertEqual(result.data.chargingLocation, "VivoCity")
        XCTAssertEqual(result.data.amountSGD, 16.20)
        XCTAssertEqual(result.data.energyKWh, 35.5)
        XCTAssertEqual(result.fieldSources[.amountSGD], .ocr)
    }

    func testOCROnlyWhenAIEmpty() {
        let ai = ExtractedSessionData()
        let ocr = HeuristicExtractionResult(
            data: ExtractedSessionData(
                chargingLocation: "Marina Bay",
                energyKWh: 20,
                amountSGD: 9.5
            ),
            strongFields: [.energyKWh, .amountSGD],
            socFromDashboardSections: false
        )

        let result = ExtractionFusionService.merge(ai: ai, ocr: ocr)

        XCTAssertEqual(result.data.chargingLocation, "Marina Bay")
        XCTAssertEqual(result.data.energyKWh, 20)
        XCTAssertEqual(result.data.amountSGD, 9.5)
    }
}
