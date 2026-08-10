import XCTest
@testable import EVAi2

final class ExcelExportServiceTests: XCTestCase {
    func testExportsWorkbookMatchingImportLayout() throws {
        let session = ChargingSession(
            chargingLocation: "HDB Blk 462A MSCP C20M, Deck 3A",
            chargerId: "1111102101",
            chargingNetwork: "Charge+",
            chargerType: "AC Charger",
            chargerPowerKW: 7.4,
            startDate: makeSingaporeDate(year: 2024, month: 11, day: 10, hour: 14, minute: 23),
            endDate: makeSingaporeDate(year: 2024, month: 11, day: 10, hour: 18, minute: 25),
            startSOCPercent: 45,
            endSOCPercent: 69,
            odometerKM: 191,
            energyKWh: 13.8,
            amountSGD: 8.4,
            sessionDuration: 14_520,
            idleDuration: 0,
            carModel: "Test Car",
            extractionConfidence: 1,
            rawAIResponse: SessionImportMetadata.encode(reference: "SG24KA9AHH", excelRow: 3)
        )

        let data = ExcelExportService.exportWorkbook(from: [session])
        let rows = try XLSXWorkbookReader.readRows(from: data)

        XCTAssertTrue(ExcelChargingLogLayout.isHeaderRow(rows[0].cells))

        let exported = rows[1].cells
        XCTAssertEqual(exported[ExcelChargingLogLayout.Column.location], session.chargingLocation)
        XCTAssertEqual(exported[ExcelChargingLogLayout.Column.chargerId], session.chargerId)
        XCTAssertEqual(exported[ExcelChargingLogLayout.Column.network], session.chargingNetwork)
        XCTAssertEqual(exported[ExcelChargingLogLayout.Column.chargerType], session.chargerType)
        XCTAssertEqual(exported[ExcelChargingLogLayout.Column.powerKW], "7.4")
        XCTAssertEqual(exported[ExcelChargingLogLayout.Column.reference], "SG24KA9AHH")
        XCTAssertEqual(exported[ExcelChargingLogLayout.Column.duration], "4 h 2 m 0 s")

        let start = try XCTUnwrap(
            ExcelSerialDateParser.combinedDateTime(
                dateSerial: exported[ExcelChargingLogLayout.Column.startDate] ?? "",
                timeSerial: exported[ExcelChargingLogLayout.Column.startTime] ?? ""
            )
        )
        let end = try XCTUnwrap(
            ExcelSerialDateParser.combinedDateTime(
                dateSerial: exported[ExcelChargingLogLayout.Column.endDate] ?? "",
                timeSerial: exported[ExcelChargingLogLayout.Column.endTime] ?? ""
            )
        )
        assertDateComponents(start, year: 2024, month: 11, day: 10, hour: 14, minute: 23)
        assertDateComponents(end, year: 2024, month: 11, day: 10, hour: 18, minute: 25)
    }

    func testRoundTripReimportsExportedWorkbook() throws {
        let session = ChargingSession(
            chargingLocation: "ORTO West Coast",
            chargerId: "222",
            chargingNetwork: "Charge+",
            chargerType: "DC Fast Charger",
            chargerPowerKW: 50,
            startDate: makeSingaporeDate(year: 2024, month: 12, day: 1, hour: 9, minute: 0),
            endDate: makeSingaporeDate(year: 2024, month: 12, day: 1, hour: 9, minute: 45),
            startSOCPercent: 20,
            endSOCPercent: 55,
            odometerKM: 0,
            energyKWh: 18.2,
            amountSGD: 12.5,
            sessionDuration: 2_700,
            idleDuration: 0,
            carModel: "Test Car",
            extractionConfidence: 1,
            rawAIResponse: SessionImportMetadata.encode(reference: "SG24KBVMQ0", excelRow: 4)
        )

        let exported = ExcelExportService.exportWorkbook(from: [session])
        let result = try ExcelImportService.importSessions(
            from: exported,
            carModel: "Test Car",
            existingSessions: []
        )

        XCTAssertEqual(result.importedCount, 1)
        let imported = try XCTUnwrap(result.sessions.first)
        XCTAssertEqual(imported.chargingLocation, session.chargingLocation)
        XCTAssertEqual(imported.chargerType, session.chargerType)
        XCTAssertEqual(imported.chargerPowerKW, session.chargerPowerKW)
        XCTAssertEqual(imported.energyKWh, session.energyKWh)
        XCTAssertEqual(imported.amountSGD, session.amountSGD)
        XCTAssertEqual(imported.sessionDuration, session.sessionDuration)
    }

    private func makeSingaporeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = ExcelSerialDateParser.testTimeZone
        return calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )) ?? .now
    }

    private func assertDateComponents(
        _ date: Date,
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int
    ) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = ExcelSerialDateParser.testTimeZone
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        XCTAssertEqual(components.year, year)
        XCTAssertEqual(components.month, month)
        XCTAssertEqual(components.day, day)
        XCTAssertEqual(components.hour, hour)
        XCTAssertEqual(components.minute, minute)
    }
}
