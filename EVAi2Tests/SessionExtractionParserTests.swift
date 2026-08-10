import XCTest
@testable import EVAi2

final class SessionExtractionParserTests: XCTestCase {
    func testParsesValidJSONPayload() throws {
        let json = """
        {
          "charging_location": "VivoCity",
          "charger_id": "SP-100",
          "charging_network": "SP Group",
          "energy_kwh": 35.5,
          "amount_sgd": 16.2,
          "start_soc_percent": 25,
          "end_soc_percent": 78,
          "car_model": "Tesla Model 3"
        }
        """

        let parsed = try SessionExtractionParser.parseJSON(from: json)
        XCTAssertEqual(parsed.chargingLocation, "VivoCity")
        XCTAssertEqual(parsed.chargerId, "SP-100")
        XCTAssertEqual(parsed.energyKWh, 35.5)
        XCTAssertEqual(parsed.amountSGD, 16.2)
    }

    func testCorruptJSONThrows() {
        XCTAssertThrowsError(try SessionExtractionParser.parseJSON(from: "{not-json"))
    }

    func testBuildPromptIncludesDashboardSOCGuidance() {
        let ocrText = """
        --- Image 1 ---
        35.5 kWh
        --- Image 2 ---
        $16.20
        --- Image 3 ---
        17%
        8:34pm
        --- Image 4 ---
        100%
        10:17am
        """
        let prompt = SessionExtractionParser.buildPrompt(ocrText: ocrText, imageCount: 4)

        XCTAssertTrue(prompt.contains("start_soc_percent"))
        XCTAssertTrue(prompt.contains("end_soc_percent"))
        XCTAssertTrue(prompt.contains("start_soc_percent = lower SOC"))
        XCTAssertTrue(prompt.contains("cruise"))
        XCTAssertTrue(prompt.contains(ocrText))
    }

    func testBuildPromptIsTextOrientedNotImageOriented() {
        let prompt = SessionExtractionParser.buildPrompt(
            ocrText: "--- Image 1 ---\n35.5 kWh",
            imageCount: 1
        )

        XCTAssertTrue(prompt.contains("cannot see the images"))
        XCTAssertTrue(prompt.contains("Worked example"))
    }
}
