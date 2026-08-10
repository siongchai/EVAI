import Foundation

enum LTAChargerCatalogImporter {
    struct LTABatchLinkResponse: Decodable {
        let link: String?
    }

    static func importCatalog(fromLTAData data: Data) throws -> SingaporeChargerCatalogFile {
        let json = try JSONSerialization.jsonObject(with: data)
        let stations = extractStations(from: json)
        var entries: [SingaporeChargerCatalogEntry] = []
        var seen = Set<String>()

        for station in stations {
            for entry in makeEntries(from: station) {
                guard seen.insert(entry.id).inserted else { continue }
                entries.append(entry)
            }
        }

        return SingaporeChargerCatalogFile(
            version: 1,
            source: "lta-datamall",
            updatedAt: ISO8601DateFormatter().string(from: .now),
            entries: entries.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending },
            networkDefaults: SingaporeChargerCatalog.loadCatalog()?.networkDefaults ?? defaultNetworkDefaults()
        )
    }

    static func defaultNetworkDefaults() -> [SingaporeChargerNetworkDefault] {
        [
            SingaporeChargerNetworkDefault(
                networkAliases: ["Charge+", "SP Group", "SPGroup"],
                locationKeywords: ["hdb", "mscp", "scp", "carpark", "ms"],
                plugType: "Type 2",
                powerRating: "AC",
                chargingSpeedKW: 7.4
            ),
            SingaporeChargerNetworkDefault(
                networkAliases: ["Charge+", "SP Group", "SPGroup"],
                locationKeywords: ["orto", "shell", "mall", "centre", "center", "office", "hub"],
                plugType: "CCS",
                powerRating: "DC",
                chargingSpeedKW: 50
            ),
            SingaporeChargerNetworkDefault(
                networkAliases: ["MNL"],
                locationKeywords: ["verandah", "residence", "condo"],
                plugType: "Type 2",
                powerRating: "AC",
                chargingSpeedKW: 7.4
            )
        ]
    }

    private static func extractStations(from json: Any) -> [[String: Any]] {
        if let root = json as? [String: Any] {
            if let value = root["value"] as? [[String: Any]] {
                return value
            }
            if let data = root["data"] as? [[String: Any]] {
                return data
            }
            if let stations = root["stations"] as? [[String: Any]] {
                return stations
            }
        }
        if let array = json as? [[String: Any]] {
            return array
        }
        return []
    }

    private static func makeEntries(from station: [String: Any]) -> [SingaporeChargerCatalogEntry] {
        let address = stringValue(station["address"])
        let name = stringValue(station["name"])
        let operatorName = stringValue(station["operator"])
        let position = stringValue(station["position"])
        let locationID = stringValue(station["locationId"])
        let chargers = station["chargers"] as? [[String: Any]] ?? []

        var entries: [SingaporeChargerCatalogEntry] = []

        for charger in chargers {
            let chargerName = stringValue(charger["name"])
            let chargingPoints = charger["chargingPoints"] as? [[String: Any]] ?? []

            for point in chargingPoints {
                let connectorID = stringValue(point["evCpId"])
                let plugType = stringValue(point["plugType"])
                let powerRating = stringValue(point["powerRating"])
                let chargingSpeed = doubleValue(point["chargingSpeed"]) ?? 0
                let entryID = [locationID, connectorID, plugType, String(chargingSpeed)]
                    .filter { !$0.isEmpty }
                    .joined(separator: "|")

                entries.append(
                    SingaporeChargerCatalogEntry(
                        id: entryID.isEmpty ? UUID().uuidString : entryID,
                        name: [name, chargerName].filter { !$0.isEmpty }.joined(separator: " · "),
                        address: address,
                        operatorName: operatorName,
                        networkAliases: networkAliases(for: operatorName),
                        position: [position, stringValue(charger["position"])]
                            .filter { !$0.isEmpty }
                            .joined(separator: " · "),
                        connectorIds: connectorID.isEmpty ? [] : [connectorID],
                        plugType: plugType,
                        powerRating: powerRating,
                        chargingSpeedKW: chargingSpeed
                    )
                )
            }
        }

        if entries.isEmpty, !name.isEmpty || !address.isEmpty {
            entries.append(
                SingaporeChargerCatalogEntry(
                    id: locationID.isEmpty ? UUID().uuidString : locationID,
                    name: name.isEmpty ? address : name,
                    address: address,
                    operatorName: operatorName,
                    networkAliases: networkAliases(for: operatorName),
                    position: position,
                    connectorIds: [],
                    plugType: "",
                    powerRating: "",
                    chargingSpeedKW: 0
                )
            )
        }

        return entries
    }

    private static func networkAliases(for operatorName: String) -> [String] {
        let trimmed = operatorName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var aliases = [trimmed]
        let lower = trimmed.lowercased()
        if lower.contains("charge") {
            aliases.append(contentsOf: ["Charge+", "SP Group"])
        }
        if lower.contains("shell") {
            aliases.append("Shell Recharge")
        }
        if lower.contains("tesla") {
            aliases.append("Tesla")
        }
        return Array(Set(aliases))
    }

    private static func stringValue(_ value: Any?) -> String {
        switch value {
        case let string as String:
            return string.trimmingCharacters(in: .whitespacesAndNewlines)
        case let number as NSNumber:
            return number.stringValue
        default:
            return ""
        }
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        switch value {
        case let double as Double:
            return double
        case let int as Int:
            return Double(int)
        case let string as String:
            return Double(string.trimmingCharacters(in: .whitespacesAndNewlines))
        case let number as NSNumber:
            return number.doubleValue
        default:
            return nil
        }
    }
}

enum LTAChargerCatalogSyncService {
    private static let accountKeyDefaultsKey = "ltaDatamallAccountKey"

    static var accountKey: String? {
        get {
            let value = UserDefaults.standard.string(forKey: accountKeyDefaultsKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return value?.isEmpty == false ? value : nil
        }
        set {
            if let newValue, !newValue.isEmpty {
                UserDefaults.standard.set(newValue, forKey: accountKeyDefaultsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: accountKeyDefaultsKey)
            }
        }
    }

    static func refreshCatalogIfConfigured() async throws -> Int {
        guard let accountKey else { return 0 }

        var request = URLRequest(url: URL(string: "https://datamall2.mytransport.sg/ltaodataservice/EVCBatch")!)
        request.setValue(accountKey, forHTTPHeaderField: "AccountKey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (linkData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let linkResponse = try JSONDecoder().decode(LTAChargerCatalogImporter.LTABatchLinkResponse.self, from: linkData)
        guard let link = linkResponse.link, let batchURL = URL(string: link) else {
            throw URLError(.fileDoesNotExist)
        }

        let (batchData, batchResponse) = try await URLSession.shared.data(from: batchURL)
        guard let batchHTTP = batchResponse as? HTTPURLResponse, (200 ..< 300).contains(batchHTTP.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let catalog = try LTAChargerCatalogImporter.importCatalog(fromLTAData: batchData)
        try SingaporeChargerCatalog.replaceCachedCatalog(catalog)
        SingaporeChargerCatalog.resetCache()
        return catalog.entries.count
    }
}
