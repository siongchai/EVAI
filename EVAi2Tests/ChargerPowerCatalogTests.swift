import XCTest
@testable import EVAi2

final class ChargerPowerCatalogTests: XCTestCase {
    func testSnapsACToNearestStandardPower() {
        XCTAssertEqual(ChargerPowerCatalog.snap(7.2, for: .acCharger), 7.4)
        XCTAssertEqual(ChargerPowerCatalog.snap(10, for: .acCharger), 11)
        XCTAssertEqual(ChargerPowerCatalog.snap(20, for: .acCharger), 22)
        XCTAssertEqual(ChargerPowerCatalog.snap(40, for: .acCharger), 43)
    }

    func testSnapsDCToNearestStandardPower() {
        XCTAssertEqual(ChargerPowerCatalog.snap(55, for: .dcFastCharger), 50)
        XCTAssertEqual(ChargerPowerCatalog.snap(90, for: .dcFastCharger), 100)
        XCTAssertEqual(ChargerPowerCatalog.snap(130, for: .dcFastCharger), 120)
        XCTAssertEqual(ChargerPowerCatalog.snap(200, for: .dcFastCharger), 180)
    }

    func testInfersChargerTypeFromPower() {
        XCTAssertEqual(ChargerPowerCatalog.inferChargerType(fromPower: 7.4), .acCharger)
        XCTAssertEqual(ChargerPowerCatalog.inferChargerType(fromPower: 50), .dcFastCharger)
        XCTAssertEqual(ChargerPowerCatalog.inferChargerType(fromPower: 150), .dcFastCharger)
    }

    func testDisplayLabelIncludesDCTier() {
        XCTAssertEqual(
            ChargerPowerCatalog.displayLabel(kilowatts: 50, chargerType: "DC Fast Charger"),
            "50 kW (Standard DC)"
        )
        XCTAssertEqual(
            ChargerPowerCatalog.displayLabel(kilowatts: 150, chargerType: "DC Fast Charger"),
            "150 kW (Ultra-Fast DC)"
        )
        XCTAssertEqual(
            ChargerPowerCatalog.displayLabel(kilowatts: 7.4, chargerType: "AC Charger"),
            "7.4 kW"
        )
    }
}
