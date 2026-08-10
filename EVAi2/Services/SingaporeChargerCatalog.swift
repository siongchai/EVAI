import Foundation

struct SingaporeChargerCatalogEntry: Codable, Equatable {
    let id: String
    let name: String
    let address: String
    let operatorName: String
    let networkAliases: [String]
    let position: String
    let connectorIds: [String]
    let plugType: String
    let powerRating: String
    let chargingSpeedKW: Double

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case address
        case operatorName = "operator"
        case networkAliases
        case position
        case connectorIds
        case plugType
        case powerRating
        case chargingSpeedKW
    }
}

struct SingaporeChargerNetworkDefault: Codable, Equatable {
    let networkAliases: [String]
    let locationKeywords: [String]
    let plugType: String
    let powerRating: String
    let chargingSpeedKW: Double
}

struct SingaporeChargerCatalogFile: Codable {
    let version: Int
    let source: String
    let updatedAt: String
    let entries: [SingaporeChargerCatalogEntry]
    let networkDefaults: [SingaporeChargerNetworkDefault]
}

struct SingaporeChargerEnrichmentResult: Equatable {
    let chargerType: String
    let chargerPowerKW: Double
    let matchSource: String
}

enum SingaporeChargerCatalog {
    private static let bundledResourceName = "SingaporeChargerCatalog"
    private static let cachedFileName = "singapore-charger-catalog.json"

    private static var cachedCatalog: SingaporeChargerCatalogFile?

    static func loadCatalog() -> SingaporeChargerCatalogFile? {
        if let cachedCatalog {
            return cachedCatalog
        }

        if let cached = loadCachedCatalog() {
            cachedCatalog = cached
            return cached
        }

        if let bundled = loadBundledCatalog() {
            cachedCatalog = bundled
            return bundled
        }

        return nil
    }

    static func replaceCachedCatalog(_ catalog: SingaporeChargerCatalogFile) throws {
        let url = cachedCatalogURL()
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(catalog)
        try data.write(to: url, options: .atomic)
        cachedCatalog = catalog
    }

    static func resetCache() {
        cachedCatalog = nil
    }

    private static func loadBundledCatalog() -> SingaporeChargerCatalogFile? {
        guard let url = Bundle.main.url(forResource: bundledResourceName, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(SingaporeChargerCatalogFile.self, from: data)
    }

    private static func loadCachedCatalog() -> SingaporeChargerCatalogFile? {
        let url = cachedCatalogURL()
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(SingaporeChargerCatalogFile.self, from: data)
    }

    private static func cachedCatalogURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("EVAi2", isDirectory: true)
            .appendingPathComponent(cachedFileName)
    }
}

enum SingaporeChargerEnrichmentService {
    static func enrich(
        location: String,
        network: String,
        chargerId: String,
        reference: String?,
        chargerType: String,
        chargerPowerKW: Double
    ) -> SingaporeChargerEnrichmentResult? {
        guard needsEnrichment(chargerType: chargerType, chargerPowerKW: chargerPowerKW) else {
            return nil
        }
        guard let catalog = SingaporeChargerCatalog.loadCatalog() else {
            return nil
        }

        let connectorCandidates = connectorCandidates(chargerId: chargerId, reference: reference)
        if let match = matchByConnector(connectorCandidates, in: catalog.entries) {
            return result(from: match, source: "connector")
        }

        if let match = matchByLocation(location: location, network: network, in: catalog.entries) {
            return result(from: match, source: "location")
        }

        if let fallback = matchNetworkDefault(location: location, network: network, in: catalog.networkDefaults) {
            let chargerType = displayChargerType(plugType: fallback.plugType, powerRating: fallback.powerRating)
            return SingaporeChargerEnrichmentResult(
                chargerType: chargerType,
                chargerPowerKW: ChargerPowerCatalog.normalizedPower(fallback.chargingSpeedKW, chargerType: chargerType),
                matchSource: "network-default"
            )
        }

        return nil
    }

    static func needsEnrichment(chargerType: String, chargerPowerKW: Double) -> Bool {
        !ChargerTypeOption.from(storedValue: chargerType).isClassified || chargerPowerKW <= 0
    }

    static func displayChargerType(plugType: String, powerRating: String) -> String {
        ChargerTypeOption.from(powerRating: powerRating, plugType: plugType).rawValue
    }

    static func normalizeText(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9\s]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func networkTokens(for network: String) -> Set<String> {
        var tokens = Set<String>()
        let normalized = normalizeText(network)
        if !normalized.isEmpty {
            tokens.insert(normalized)
        }

        let lower = network.lowercased()
        if lower.contains("charge+") || lower.contains("chargeplus") || lower.contains("charge plus") {
            tokens.formUnion(["charge+", "chargeplus", "charge plus", "sp group", "spgroup"])
        }
        if lower.contains("mnl") {
            tokens.formUnion(["mnl"])
        }
        if lower.contains("orto") {
            tokens.formUnion(["orto"])
        }
        if lower.contains("shell") {
            tokens.formUnion(["shell", "shell recharge"])
        }
        if lower.contains("tesla") {
            tokens.formUnion(["tesla"])
        }
        if lower.contains("sp group") || lower.hasPrefix("sp ") {
            tokens.formUnion(["sp group", "spgroup", "charge+"])
        }

        return tokens
    }

    private static func connectorCandidates(chargerId: String, reference: String?) -> [String] {
        var values = [chargerId, reference ?? ""]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
            .filter { !$0.isEmpty }

        for value in values {
            if value.hasPrefix("SG"), value.count >= 8 {
                values.append(String(value.prefix(8)))
            }
        }

        return Array(Set(values))
    }

    private static func matchByConnector(
        _ candidates: [String],
        in entries: [SingaporeChargerCatalogEntry]
    ) -> SingaporeChargerCatalogEntry? {
        guard !candidates.isEmpty else { return nil }

        for entry in entries {
            let connectorIDs = entry.connectorIds
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
            for candidate in candidates {
                if connectorIDs.contains(where: { $0 == candidate || $0.hasPrefix(candidate) || candidate.hasPrefix($0) }) {
                    return entry
                }
            }
        }

        return nil
    }

    private static func matchByLocation(
        location: String,
        network: String,
        in entries: [SingaporeChargerCatalogEntry]
    ) -> SingaporeChargerCatalogEntry? {
        let normalizedLocation = normalizeText(location)
        let networkTokenSet = networkTokens(for: network)
        guard !normalizedLocation.isEmpty else { return nil }

        var best: (entry: SingaporeChargerCatalogEntry, score: Double)?

        for entry in entries {
            let entryNetworks = Set(entry.networkAliases.flatMap { networkTokens(for: $0) })
                .union(networkTokens(for: entry.operatorName))

            guard entryNetworks.isEmpty || !networkTokenSet.isDisjoint(with: entryNetworks) else {
                continue
            }

            let entryTexts = [entry.name, entry.address, entry.position]
                .map(normalizeText)
                .filter { !$0.isEmpty }

            var score = 0.0
            for text in entryTexts {
                if text == normalizedLocation {
                    score = max(score, 1.0)
                } else if text.contains(normalizedLocation) || normalizedLocation.contains(text) {
                    score = max(score, 0.85)
                } else {
                    score = max(score, tokenOverlapScore(normalizedLocation, text))
                }
            }

            if score >= 0.55, score > (best?.score ?? 0) {
                best = (entry, score)
            }
        }

        return best?.entry
    }

    private static func matchNetworkDefault(
        location: String,
        network: String,
        in defaults: [SingaporeChargerNetworkDefault]
    ) -> SingaporeChargerNetworkDefault? {
        let normalizedLocation = normalizeText(location)
        let networkTokenSet = networkTokens(for: network)

        for rule in defaults {
            let ruleNetworks = Set(rule.networkAliases.flatMap { networkTokens(for: $0) })
            guard !networkTokenSet.isDisjoint(with: ruleNetworks) else { continue }

            let keywords = rule.locationKeywords.map(normalizeText).filter { !$0.isEmpty }
            guard keywords.contains(where: { normalizedLocation.contains($0) }) else { continue }
            return rule
        }

        return nil
    }

    private static func tokenOverlapScore(_ lhs: String, _ rhs: String) -> Double {
        let left = Set(lhs.split(separator: " ").map(String.init))
        let right = Set(rhs.split(separator: " ").map(String.init))
        guard !left.isEmpty, !right.isEmpty else { return 0 }

        let intersection = left.intersection(right).count
        let union = left.union(right).count
        return Double(intersection) / Double(union)
    }

    private static func result(from entry: SingaporeChargerCatalogEntry, source: String) -> SingaporeChargerEnrichmentResult {
        let chargerType = displayChargerType(plugType: entry.plugType, powerRating: entry.powerRating)
        return SingaporeChargerEnrichmentResult(
            chargerType: chargerType,
            chargerPowerKW: ChargerPowerCatalog.normalizedPower(entry.chargingSpeedKW, chargerType: chargerType),
            matchSource: source
        )
    }
}
