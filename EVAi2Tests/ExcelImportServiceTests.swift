import XCTest
@testable import EVAi2

final class ExcelDurationParserTests: XCTestCase {
    func testParsesHourMinuteSecondFormatIgnoringSeconds() {
        XCTAssertEqual(ExcelDurationParser.durationSeconds(from: "4 h 2 m 1 s"), 14_520)
    }

    func testParsesMinuteSecondFormatIgnoringSeconds() {
        XCTAssertEqual(ExcelDurationParser.durationSeconds(from: "52 m 14 s"), 3_120)
    }

    func testParsesCompactHourMinuteFormat() {
        XCTAssertEqual(ExcelDurationParser.durationSeconds(from: "8h 1m"), 28_860)
    }

    func testParsesHourMinuteWithoutSeconds() {
        XCTAssertEqual(ExcelDurationParser.durationSeconds(from: "8 h 55 m"), 32_100)
    }

    func testParsesExcelDayFractionToWholeMinutes() {
        XCTAssertEqual(ExcelDurationParser.durationSeconds(from: "0.3173611111111111"), 27_420)
    }
}

final class ExcelImportServiceTests: XCTestCase {
    private var projectRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var sampleWorkbookURL: URL {
        let newFormat = projectRootURL.appendingPathComponent("EV Charging logs 4 2.xlsx")
        if FileManager.default.fileExists(atPath: newFormat.path) {
            return newFormat
        }
        return projectRootURL.appendingPathComponent("EV Charging logs 4.xlsx")
    }

    private var legacyWorkbookURL: URL {
        projectRootURL.appendingPathComponent("EV Charging logs 4.xlsx")
    }

    func testImportsSampleWorkbook() throws {
        guard FileManager.default.fileExists(atPath: sampleWorkbookURL.path) else {
            throw XCTSkip("Sample workbook not found at \(sampleWorkbookURL.path)")
        }

        let data = try Data(contentsOf: sampleWorkbookURL)
        let result = try ExcelImportService.importSessions(
            from: data,
            carModel: "Test Car",
            existingSessions: []
        )

        XCTAssertGreaterThanOrEqual(result.importedCount, 140)
        XCTAssertEqual(result.skippedInvalid, 1)
        XCTAssertEqual(result.updatedCount, 0)

        let timeZone = ExcelSerialDateParser.testTimeZone
        let first = try XCTUnwrap(result.sessions.first)
        XCTAssertFalse(first.chargingLocation.isEmpty)
        XCTAssertEqual(first.carModel, "Test Car")
        XCTAssertEqual(first.idleDuration, 0)
        XCTAssertEqual(first.sessionDuration, 14_520)
        XCTAssertEqual(first.chargingNetwork, "Charge+")
        XCTAssertEqual(first.chargerType, "AC Charger")
        XCTAssertEqual(first.chargerPowerKW, 7.4)
        assertDateComponents(
            first.startDate,
            year: 2024, month: 11, day: 10, hour: 14, minute: 23,
            timeZone: timeZone
        )
        assertDateComponents(
            first.endDate,
            year: 2024, month: 11, day: 10, hour: 18, minute: 25,
            timeZone: timeZone
        )
    }

    private func assertDateComponents(
        _ date: Date,
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        timeZone: TimeZone,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: timeZone, from: date)
        XCTAssertEqual(components.year, year, file: file, line: line)
        XCTAssertEqual(components.month, month, file: file, line: line)
        XCTAssertEqual(components.day, day, file: file, line: line)
        XCTAssertEqual(components.hour, hour, file: file, line: line)
        XCTAssertEqual(components.minute, minute, file: file, line: line)
    }

    func testImportsCrossMidnightSessionUsingEndDateColumn() throws {
        guard FileManager.default.fileExists(atPath: sampleWorkbookURL.path) else {
            throw XCTSkip("Sample workbook not found at \(sampleWorkbookURL.path)")
        }

        let data = try Data(contentsOf: sampleWorkbookURL)
        let result = try ExcelImportService.importSessions(
            from: data,
            carModel: "Test Car",
            existingSessions: []
        )

        let session = try XCTUnwrap(
            result.sessions.first { SessionImportMetadata.excelRow(from: $0.rawAIResponse) == 121 },
            "Expected imported row 121."
        )

        let timeZone = ExcelSerialDateParser.testTimeZone
        assertDateComponents(
            session.startDate,
            year: 2025, month: 11, day: 17, hour: 22, minute: 7,
            timeZone: timeZone
        )
        assertDateComponents(
            session.endDate,
            year: 2025, month: 11, day: 18, hour: 7, minute: 3,
            timeZone: timeZone
        )
        XCTAssertEqual(session.sessionDuration, 32_100)
    }

    func testImportsCrossMidnightSessionWhenStartDateAndTimeSerialsDiffer() throws {
        guard FileManager.default.fileExists(atPath: sampleWorkbookURL.path) else {
            throw XCTSkip("Sample workbook not found at \(sampleWorkbookURL.path)")
        }

        let data = try Data(contentsOf: sampleWorkbookURL)
        let result = try ExcelImportService.importSessions(
            from: data,
            carModel: "Test Car",
            existingSessions: []
        )

        let session = try XCTUnwrap(
            result.sessions.first { SessionImportMetadata.excelRow(from: $0.rawAIResponse) == 128 },
            "Expected imported row 128."
        )

        let timeZone = ExcelSerialDateParser.testTimeZone
        assertDateComponents(
            session.startDate,
            year: 2026, month: 1, day: 21, hour: 20, minute: 23,
            timeZone: timeZone
        )
        assertDateComponents(
            session.endDate,
            year: 2026, month: 1, day: 22, hour: 3, minute: 57,
            timeZone: timeZone
        )
    }

    func testUpdatesExistingRecordsOnSecondImport() throws {
        guard FileManager.default.fileExists(atPath: sampleWorkbookURL.path) else {
            throw XCTSkip("Sample workbook not found at \(sampleWorkbookURL.path)")
        }

        let data = try Data(contentsOf: sampleWorkbookURL)
        let first = try ExcelImportService.importSessions(
            from: data,
            carModel: "Test Car",
            existingSessions: []
        )

        let existing = first.sessions
        existing[0].startDate = existing[0].startDate.addingTimeInterval(28_800)

        let second = try ExcelImportService.importSessions(
            from: data,
            carModel: "Test Car",
            existingSessions: existing
        )

        XCTAssertEqual(second.importedCount, 0)
        XCTAssertGreaterThan(second.updatedCount, 0)

        let timeZone = ExcelSerialDateParser.testTimeZone
        assertDateComponents(
            existing[0].startDate,
            year: 2024, month: 11, day: 10, hour: 14, minute: 23,
            timeZone: timeZone
        )
    }

    func testImportsLegacyWorkbookWithoutNetworkColumns() throws {
        guard FileManager.default.fileExists(atPath: legacyWorkbookURL.path) else {
            throw XCTSkip("Legacy workbook not found at \(legacyWorkbookURL.path)")
        }

        let data = try Data(contentsOf: legacyWorkbookURL)
        let result = try ExcelImportService.importSessions(
            from: data,
            carModel: "Test Car",
            existingSessions: []
        )

        let first = try XCTUnwrap(result.sessions.first)
        XCTAssertEqual(first.chargingNetwork, "HDB")
        XCTAssertEqual(first.chargerType, "AC Charger")
        XCTAssertEqual(first.chargerPowerKW, 7.4)
    }
}

final class ExcelSerialDateParserTests: XCTestCase {
    private var timeZone: TimeZone { ExcelSerialDateParser.testTimeZone }

    func testParsesExcelSerialDateTime() {
        let date = ExcelSerialDateParser.date(fromExcelSerial: "45606.599305555559")
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: timeZone, from: date!)
        XCTAssertEqual(components.year, 2024)
        XCTAssertEqual(components.month, 11)
        XCTAssertEqual(components.day, 10)
        XCTAssertEqual(components.hour, 14)
        XCTAssertEqual(components.minute, 23)
    }

    func testCombinesStartDateAndStartTimeColumns() {
        let date = ExcelSerialDateParser.combinedDateTime(
            dateSerial: "45606.599305555559",
            timeSerial: "45606.599305555559"
        )
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: timeZone, from: date!)
        XCTAssertEqual(components.year, 2024)
        XCTAssertEqual(components.month, 11)
        XCTAssertEqual(components.day, 10)
        XCTAssertEqual(components.hour, 14)
        XCTAssertEqual(components.minute, 23)
    }

    func testCombinesDateOnlyWithSeparateTimeSerial() {
        let date = ExcelSerialDateParser.combinedDateTime(
            dateSerial: "45606",
            timeSerial: "45606.767361111109"
        )
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: timeZone, from: date!)
        XCTAssertEqual(components.year, 2024)
        XCTAssertEqual(components.month, 11)
        XCTAssertEqual(components.day, 10)
        XCTAssertEqual(components.hour, 18)
        XCTAssertEqual(components.minute, 25)
    }

    func testCombinesStartDateColumnDayWithMismatchedTimeSerialDay() {
        let date = ExcelSerialDateParser.combinedDateTime(
            dateSerial: "46043",
            timeSerial: "46046.849305555559"
        )
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: timeZone, from: date!)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.day, 21)
        XCTAssertEqual(components.hour, 20)
        XCTAssertEqual(components.minute, 23)
    }

    func testCombinesEndDateColumnDayWithMismatchedTimeSerialDay() {
        let date = ExcelSerialDateParser.combinedDateTime(
            dateSerial: "46044",
            timeSerial: "46046.164583333331"
        )
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: timeZone, from: date!)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.day, 22)
        XCTAssertEqual(components.hour, 3)
        XCTAssertEqual(components.minute, 57)
    }

    func testTimeOfDayFractionUsesPureFractionWhenSerialLessThanOne() {
        XCTAssertEqual(ExcelSerialDateParser.timeOfDayFraction(from: 0.5), 0.5, accuracy: 0.000_001)
    }
}
