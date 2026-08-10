import XCTest
@testable import EVAi2

final class SessionCalculatorTests: XCTestCase {
    func testChargingEndDateFromStartPlusActive() {
        let start = makeDate(hour: 20, minute: 24)
        let end = SessionCalculator.chargingEndDate(
            startDate: start,
            totalSessionMinutes: 113,
            idleMinutes: 38
        )

        XCTAssertEqual(end, makeDate(hour: 21, minute: 39))
    }

    func testEditableSessionDraftPrefersComputedEndOverAIEndTime() {
        let extracted = ExtractedSessionData(
            startDate: "2024-11-10",
            startTime: "8:24 PM",
            endDate: "2024-11-10",
            endTime: "10:17 PM",
            sessionDuration: "113",
            idleDuration: "38"
        )

        let draft = EditableSessionDraft(from: extracted)
        // 10:17 PM is total session close; active charging ends at 8:24 PM + 75 min = 9:39 PM.
        XCTAssertEqual(draft.endDate, makeDate(year: 2024, month: 11, day: 10, hour: 21, minute: 39))
    }

    func testApplyAutoCalculationsSyncsEndWhenDurationsChange() {
        var draft = EditableSessionDraft()
        draft.startDate = makeDate(hour: 20, minute: 24)
        draft.sessionDurationMinutes = "113"
        draft.idleDurationMinutes = "38"

        SessionCalculator.applyAutoCalculations(to: &draft)

        XCTAssertEqual(draft.endDate, makeDate(hour: 21, minute: 39))
    }

    func testApplyAutoCalculationsUpdatesEndWhenStartChanges() {
        var draft = EditableSessionDraft()
        draft.startDate = makeDate(hour: 20, minute: 24)
        draft.sessionDurationMinutes = "75"
        draft.idleDurationMinutes = "0"
        SessionCalculator.applyAutoCalculations(to: &draft)

        draft.startDate = makeDate(hour: 21, minute: 0)
        SessionCalculator.applyAutoCalculations(to: &draft)

        XCTAssertEqual(draft.endDate, makeDate(hour: 22, minute: 15))
    }

    private func makeDate(
        year: Int = 2024,
        month: Int = 11,
        day: Int = 10,
        hour: Int,
        minute: Int
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = 0
        return Calendar(identifier: .gregorian).date(from: components)!
    }
}
