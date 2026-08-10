import Foundation

enum SessionImportMetadata {
    struct Payload: Codable {
        let importReference: String?
        let source: String
        let importedAt: Date
        let excelRow: Int?
    }

    static func encode(reference: String?, excelRow: Int) -> String {
        let payload = Payload(
            importReference: reference?.nilIfEmpty,
            source: "excel",
            importedAt: .now,
            excelRow: excelRow
        )
        guard let data = try? JSONEncoder().encode(payload) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    static func payload(from rawAIResponse: String) -> Payload? {
        guard !rawAIResponse.isEmpty, !rawAIResponse.hasPrefix("enc:v1:") else { return nil }
        guard let data = rawAIResponse.data(using: .utf8),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            return nil
        }
        return payload
    }

    static func importReference(from rawAIResponse: String) -> String? {
        payload(from: rawAIResponse)?.importReference
    }

    static func excelRow(from rawAIResponse: String) -> Int? {
        payload(from: rawAIResponse)?.excelRow
    }
}

struct ExcelImportRow: Equatable {
    let rowIndex: Int
    let startDate: Date
    let endDate: Date
    let sessionDurationSeconds: Int
    let startSOCPercent: Double
    let endSOCPercent: Double
    let odometerKM: Double
    let chargingLocation: String
    let chargerId: String
    let chargingNetwork: String
    let chargerType: String
    let chargerPowerKW: Double
    let amountSGD: Double
    let energyKWh: Double
    let reference: String?
}

struct ExcelImportResult {
    let importedCount: Int
    let updatedCount: Int
    let skippedInvalid: Int
    /// New sessions to insert into the model context.
    let sessions: [ChargingSession]
    let warnings: [String]
}

enum ExcelImportError: LocalizedError {
    case unreadableFile
    case invalidWorkbook

    var errorDescription: String? {
        switch self {
        case .unreadableFile: "Unable to read the selected Excel file."
        case .invalidWorkbook: "The Excel file does not contain recognizable charging session data."
        }
    }
}

enum ExcelImportService {
    private typealias Column = ExcelChargingLogLayout.Column

    static func importSessions(
        from workbookData: Data,
        carModel: String,
        existingSessions: [ChargingSession]
    ) throws -> ExcelImportResult {
        let rows = try XLSXWorkbookReader.readRows(from: workbookData)
        guard rows.contains(where: { $0.rowIndex == 1 && isHeaderRow($0.cells) }) else {
            throw ExcelImportError.invalidWorkbook
        }

        var lookup = ExistingSessionLookup(sessions: existingSessions)

        var sessions: [ChargingSession] = []
        var updatedCount = 0
        var skippedInvalid = 0
        var warnings: [String] = []

        for row in rows where row.rowIndex > 1 {
            switch parseRow(row) {
            case .success(let parsed):
                if let existing = lookup.match(for: parsed) {
                    applyExcelRow(parsed, to: existing, carModel: carModel)
                    lookup.register(existing, for: parsed)
                    updatedCount += 1
                    continue
                }

                let session = makeSession(from: parsed, carModel: carModel)
                sessions.append(session)
                lookup.register(session, for: parsed)

            case .failure(let reason):
                skippedInvalid += 1
                if case .message(let text) = reason {
                    warnings.append("Row \(row.rowIndex): \(text)")
                }
            }
        }

        guard !sessions.isEmpty || updatedCount > 0 || skippedInvalid > 0 else {
            throw ExcelImportError.invalidWorkbook
        }

        return ExcelImportResult(
            importedCount: sessions.count,
            updatedCount: updatedCount,
            skippedInvalid: skippedInvalid,
            sessions: sessions,
            warnings: warnings
        )
    }

    // MARK: - Parsing

    private enum RowParseFailure: Error {
        case message(String)
    }

    private static func parseRow(_ row: XLSXWorksheetRow) -> Result<ExcelImportRow, RowParseFailure> {
        let cells = row.cells
        let location = cells[Column.location]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !location.isEmpty else {
            return .failure(.message("Missing charging station."))
        }

        guard let startDate = ExcelSerialDateParser.combinedDateTime(
            dateSerial: cells[Column.startDate] ?? "",
            timeSerial: cells[Column.startTime] ?? cells[Column.startDate] ?? ""
        ) else {
            return .failure(.message("Missing or invalid start date/time."))
        }

        var endDate = ExcelSerialDateParser.combinedDateTime(
            dateSerial: cells[Column.endDate] ?? "",
            timeSerial: cells[Column.endTime] ?? cells[Column.endDate] ?? ""
        )
        let durationSeconds = ExcelDurationParser.durationSeconds(from: cells[Column.duration] ?? "")
        let hasExplicitEndDateTime = !(cells[Column.endDate] ?? "").isEmpty
            && !(cells[Column.endTime] ?? "").isEmpty

        if endDate == nil, let durationSeconds, durationSeconds > 0 {
            endDate = startDate.addingTimeInterval(TimeInterval(durationSeconds))
        }

        guard var resolvedEnd = endDate else {
            return .failure(.message("Missing or invalid end date/time."))
        }

        // Only infer a next-day end when end time was derived without an explicit end date column.
        if !hasExplicitEndDateTime, resolvedEnd < startDate {
            resolvedEnd = resolvedEnd.addingTimeInterval(86_400)
        }

        let computedDuration = ExcelDurationParser.truncateToWholeMinutes(
            max(0, Int(resolvedEnd.timeIntervalSince(startDate)))
        )
        let sessionDurationSeconds = durationSeconds ?? computedDuration

        let energy = Double(cells[Column.energy] ?? "") ?? 0
        let cost = Double(cells[Column.cost] ?? "") ?? 0
        let startSOC = Double(cells[Column.startSOC] ?? "") ?? 0
        let endSOC = Double(cells[Column.endSOC] ?? "") ?? 0

        if sessionDurationSeconds == 0, energy == 0, cost == 0, startSOC == 0 {
            return .failure(.message("Incomplete session row."))
        }

        let network = trimmedCell(cells[Column.network])
        let chargerType = trimmedCell(cells[Column.chargerType])
        let chargerPowerKW = Double(cells[Column.powerKW] ?? "") ?? 0
        let chargerId = cells[Column.chargerId]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let reference = cells[Column.reference]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedNetwork = resolvedNetwork(from: network, location: location)
        let enriched = enrichChargerDetails(
            location: location,
            network: resolvedNetwork,
            chargerId: chargerId,
            reference: reference,
            chargerType: chargerType,
            chargerPowerKW: chargerPowerKW
        )

        return .success(
            ExcelImportRow(
                rowIndex: row.rowIndex,
                startDate: startDate,
                endDate: resolvedEnd,
                sessionDurationSeconds: sessionDurationSeconds,
                startSOCPercent: startSOC,
                endSOCPercent: endSOC,
                odometerKM: Double(cells[Column.odometer] ?? "") ?? 0,
                chargingLocation: location,
                chargerId: chargerId,
                chargingNetwork: resolvedNetwork,
                chargerType: enriched.chargerType,
                chargerPowerKW: enriched.chargerPowerKW,
                amountSGD: cost,
                energyKWh: energy,
                reference: reference
            )
        )
    }

    private static func enrichChargerDetails(
        location: String,
        network: String,
        chargerId: String,
        reference: String?,
        chargerType: String,
        chargerPowerKW: Double
    ) -> (chargerType: String, chargerPowerKW: Double) {
        let trimmedType = chargerType.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasType = ChargerTypeOption.from(storedValue: trimmedType).isClassified
        let hasPower = chargerPowerKW > 0

        if hasType, hasPower {
            return (
                ChargerTypeOption.normalizedStoredValue(trimmedType),
                ChargerPowerCatalog.normalizedPower(chargerPowerKW, chargerType: trimmedType)
            )
        }

        guard let enrichment = SingaporeChargerEnrichmentService.enrich(
            location: location,
            network: network,
            chargerId: chargerId,
            reference: reference,
            chargerType: hasType ? trimmedType : ChargerTypeOption.others.rawValue,
            chargerPowerKW: chargerPowerKW
        ) else {
            return (
                hasType ? ChargerTypeOption.normalizedStoredValue(trimmedType) : ChargerTypeOption.others.rawValue,
                hasPower ? chargerPowerKW : 0
            )
        }

        return (
            hasType ? ChargerTypeOption.normalizedStoredValue(trimmedType) : enrichment.chargerType,
            hasPower
                ? ChargerPowerCatalog.normalizedPower(chargerPowerKW, chargerType: hasType ? trimmedType : enrichment.chargerType)
                : ChargerPowerCatalog.normalizedPower(enrichment.chargerPowerKW, chargerType: hasType ? trimmedType : enrichment.chargerType)
        )
    }

    private static func trimmedCell(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func resolvedNetwork(from network: String, location: String) -> String {
        if !network.isEmpty { return network }
        return inferNetwork(from: location)
    }

    private static func makeSession(from row: ExcelImportRow, carModel: String) -> ChargingSession {
        ChargingSession(
            chargingLocation: row.chargingLocation,
            chargerId: normalizedChargerId(row.chargerId),
            chargingNetwork: row.chargingNetwork,
            chargerType: row.chargerType,
            chargerPowerKW: row.chargerPowerKW,
            startDate: row.startDate,
            endDate: row.endDate,
            startSOCPercent: row.startSOCPercent,
            endSOCPercent: row.endSOCPercent,
            odometerKM: row.odometerKM,
            energyKWh: row.energyKWh,
            amountSGD: row.amountSGD,
            sessionDuration: row.sessionDurationSeconds,
            idleDuration: 0,
            carModel: carModel.isEmpty ? "Unknown Car" : carModel,
            extractionConfidence: 1,
            rawAIResponse: SessionImportMetadata.encode(reference: row.reference, excelRow: row.rowIndex)
        )
    }

    private static func applyExcelRow(_ row: ExcelImportRow, to session: ChargingSession, carModel: String) {
        session.chargingLocation = row.chargingLocation
        session.chargerId = normalizedChargerId(row.chargerId)
        session.chargingNetwork = row.chargingNetwork
        session.chargerType = row.chargerType
        session.chargerPowerKW = row.chargerPowerKW
        session.startDate = row.startDate
        session.endDate = row.endDate
        session.startSOCPercent = row.startSOCPercent
        session.endSOCPercent = row.endSOCPercent
        session.odometerKM = row.odometerKM
        session.energyKWh = row.energyKWh
        session.amountSGD = row.amountSGD
        session.sessionDuration = row.sessionDurationSeconds
        session.idleDuration = 0
        session.carModel = carModel.isEmpty ? session.carModel : carModel
        session.extractionConfidence = 1
        session.rawAIResponse = SessionImportMetadata.encode(reference: row.reference, excelRow: row.rowIndex)
        session.updatedAt = .now
    }

    private static func normalizedChargerId(_ value: String) -> String {
        value.isEmpty ? "UNKNOWN" : value
    }

    private static func isHeaderRow(_ cells: [String: String]) -> Bool {
        ExcelChargingLogLayout.isHeaderRow(cells)
    }

    private static func inferNetwork(from location: String) -> String {
        let lower = location.lowercased()
        if lower.contains("orto") { return "ORTO" }
        if lower.contains("shell") { return "Shell Recharge" }
        if lower.contains("charge+") || lower.contains("charge plus") { return "Charge+" }
        if lower.contains("sp group") || lower.hasPrefix("sp ") { return "SP Group" }
        if lower.contains("tesla") { return "Tesla" }
        if lower.contains("hdb") { return "HDB" }
        return "Imported"
    }

    private static func sessionFingerprint(for row: ExcelImportRow) -> String {
        "\(Int(row.startDate.timeIntervalSince1970))|\(row.chargingLocation.lowercased())|\(row.energyKWh)|\(row.amountSGD)"
    }

    private static func sessionFingerprint(for session: ChargingSession) -> String {
        "\(Int(session.startDate.timeIntervalSince1970))|\(session.chargingLocation.lowercased())|\(session.energyKWh)|\(session.amountSGD)"
    }

    /// Matches incoming Excel rows to sessions already in the database.
    private struct ExistingSessionLookup {
        private var byReference: [String: ChargingSession] = [:]
        private var byExcelRow: [Int: ChargingSession] = [:]
        private var byFingerprint: [String: ChargingSession] = [:]

        init(sessions: [ChargingSession]) {
            for session in sessions {
                if let reference = SessionImportMetadata.importReference(from: session.rawAIResponse)?.nilIfEmpty {
                    byReference[reference] = session
                }
                if let excelRow = SessionImportMetadata.excelRow(from: session.rawAIResponse) {
                    byExcelRow[excelRow] = session
                }
                byFingerprint[ExcelImportService.sessionFingerprint(for: session)] = session
            }
        }

        func match(for row: ExcelImportRow) -> ChargingSession? {
            if let reference = row.reference?.nilIfEmpty, let session = byReference[reference] {
                return session
            }
            if let session = byExcelRow[row.rowIndex] {
                return session
            }
            return byFingerprint[ExcelImportService.sessionFingerprint(for: row)]
        }

        mutating func register(_ session: ChargingSession, for row: ExcelImportRow) {
            if let reference = row.reference?.nilIfEmpty {
                byReference[reference] = session
            }
            byExcelRow[row.rowIndex] = session
            byFingerprint[ExcelImportService.sessionFingerprint(for: row)] = session
        }
    }
}
