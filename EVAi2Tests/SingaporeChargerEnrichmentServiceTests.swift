import XCTest
@testable import EVAi2

final class SingaporeChargerEnrichmentServiceTests: XCTestCase {
    func testEnrichesKnownHDBLocationFromBundledCatalog() {
        let result = SingaporeChargerEnrichmentService.enrich(
            location: "HDB Blk 462A MSCP C20M, Deck 3A",
            network: "Charge+",
            chargerId: "1111102101",
            reference: "SG24KA9AHH",
            chargerType: "Others",
            chargerPowerKW: 0
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.chargerType, "AC Charger")
        XCTAssertEqual(result?.chargerPowerKW, 7.4)
    }

    func testEnrichesORTOLocationAsDC() {
        let result = SingaporeChargerEnrichmentService.enrich(
            location: "ORTO West Coast",
            network: "Charge+",
            chargerId: "222",
            reference: nil,
            chargerType: "",
            chargerPowerKW: 0
        )

        XCTAssertEqual(result?.chargerType, "DC Fast Charger")
        XCTAssertEqual(result?.chargerPowerKW, 50)
    }

    func testDoesNotOverrideProvidedChargerDetails() {
        XCTAssertNil(
            SingaporeChargerEnrichmentService.enrich(
                location: "ORTO West Coast",
                network: "Charge+",
                chargerId: "222",
                reference: nil,
                chargerType: "DC Fast",
                chargerPowerKW: 120
            )
        )
    }

    func testDisplayChargerTypeUsesLTACategories() {
        XCTAssertEqual(
            SingaporeChargerEnrichmentService.displayChargerType(plugType: "Type 2", powerRating: "AC"),
            "AC Charger"
        )
        XCTAssertEqual(
            SingaporeChargerEnrichmentService.displayChargerType(plugType: "CCS", powerRating: "DC"),
            "DC Fast Charger"
        )
    }

    func testParsesLTAStationPayloadIntoCatalogEntries() throws {
        let json = """
        {
          "value": [
            {
              "address": "123 Road A Singapore 123456",
              "name": "123 Road A",
              "operator": "Charge+",
              "position": "Deck 3A",
              "locationId": "123456123456",
              "chargers": [
                {
                  "name": "Charger A",
                  "chargingPoints": [
                    {
                      "evCpId": "R123456A-001",
                      "plugType": "Type 2",
                      "powerRating": "AC",
                      "chargingSpeed": 7.4
                    }
                  ]
                }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let catalog = try LTAChargerCatalogImporter.importCatalog(fromLTAData: json)
        XCTAssertEqual(catalog.entries.count, 1)
        XCTAssertEqual(catalog.entries[0].plugType, "Type 2")
        XCTAssertEqual(catalog.entries[0].chargingSpeedKW, 7.4)
        XCTAssertEqual(catalog.entries[0].connectorIds, ["R123456A-001"])
    }
}
