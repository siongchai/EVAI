import XCTest
@testable import EVAi2

final class DurationParsingServiceTests: XCTestCase {
    func testMinuteSecondTextFormats() {
        XCTAssertEqual(DurationParsingService.parseToMinutes(from: "37 min 53 sec"), "37")
        XCTAssertEqual(DurationParsingService.parseToMinutes(from: "37m 53s"), "37")
        XCTAssertEqual(DurationParsingService.parseToMinutes(from: "37 mins 53 secs"), "37")
    }

    func testColonMinuteSecond() {
        XCTAssertEqual(DurationParsingService.parseToMinutes(from: "37:53"), "37")
        XCTAssertEqual(DurationParsingService.parseToMinutes(from: "1:53"), "113")
    }

    func testHourMinuteFormats() {
        XCTAssertEqual(DurationParsingService.parseToMinutes(from: "1h 53m"), "113")
        XCTAssertEqual(DurationParsingService.parseToMinutes(from: "1 h 53 min"), "113")
    }

    func testPlainMinutes() {
        XCTAssertEqual(DurationParsingService.parseToMinutes(from: "113"), "113")
        XCTAssertEqual(DurationParsingService.parseToMinutes(from: "52"), "52")
    }

    func testAIConcatenationMistake3753() {
        XCTAssertEqual(DurationParsingService.parseToMinutes(from: "3753"), "37")
        XCTAssertEqual(DurationParsingService.parseToMinutesValue(from: "3753"), 37)
    }

    func testSessionDataParserDelegatesToDurationParsingService() {
        XCTAssertEqual(SessionDataParser.durationMinutes(from: "3753"), "37")
        XCTAssertEqual(SessionDataParser.durationMinutesValue(from: "37 min 53 sec"), 37)
    }

    func testParserNormalizesIdleDurationFromJSON() throws {
        let json = """
        {
          "session_duration": "113",
          "idle_duration": "3753"
        }
        """

        let parsed = try SessionExtractionParser.parseJSON(from: json)
        XCTAssertEqual(parsed.sessionDuration, "113")
        XCTAssertEqual(parsed.idleDuration, "37")
    }

    func testParserNormalizesNumericIdleDurationFromJSON() throws {
        let json = """
        {
          "session_duration": 113,
          "idle_duration": 3753
        }
        """

        let parsed = try SessionExtractionParser.parseJSON(from: json)
        XCTAssertEqual(parsed.sessionDuration, "113")
        XCTAssertEqual(parsed.idleDuration, "37")
    }
}
