import XCTest
@testable import EVAi2

final class ChargerTypeOptionTests: XCTestCase {
    func testMapsLegacyPlugTypesToLTACategories() {
        XCTAssertEqual(ChargerTypeOption.from(storedValue: "Type 2"), .acCharger)
        XCTAssertEqual(ChargerTypeOption.from(storedValue: "CCS"), .dcFastCharger)
        XCTAssertEqual(ChargerTypeOption.from(storedValue: "CHAdeMO"), .dcFastCharger)
        XCTAssertEqual(ChargerTypeOption.from(storedValue: "DC Fast"), .dcFastCharger)
    }

    func testMapsLTALabelsDirectly() {
        XCTAssertEqual(ChargerTypeOption.from(storedValue: "AC Charger"), .acCharger)
        XCTAssertEqual(ChargerTypeOption.from(storedValue: "DC Fast Charger"), .dcFastCharger)
    }

    func testUsesPowerRatingWhenAvailable() {
        XCTAssertEqual(
            ChargerTypeOption.from(powerRating: "AC", plugType: "Type 2"),
            .acCharger
        )
        XCTAssertEqual(
            ChargerTypeOption.from(powerRating: "DC", plugType: "CCS"),
            .dcFastCharger
        )
        XCTAssertEqual(
            ChargerTypeOption.from(powerRating: "", plugType: ""),
            .others
        )
    }

    func testMapsUnknownAndEmptyToOthers() {
        XCTAssertEqual(ChargerTypeOption.from(storedValue: ""), .others)
        XCTAssertEqual(ChargerTypeOption.from(storedValue: "Unknown"), .others)
        XCTAssertEqual(ChargerTypeOption.normalizedOptional(nil), "Others")
    }
}
