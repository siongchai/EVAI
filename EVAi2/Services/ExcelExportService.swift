import Foundation

enum ExcelExportService {
    static func exportWorkbook(from sessions: [ChargingSession]) -> Data {
        var rows: [[String: XLSXCellValue]] = [headerRow()]

        let sorted = sessions.sorted {
            if $0.startDate != $1.startDate {
                return $0.startDate < $1.startDate
            }
            return $0.createdAt < $1.createdAt
        }

        for session in sorted {
            rows.append(dataRow(for: session))
        }

        return XLSXWorkbookWriter.writeWorkbook(rows: rows)
    }

    private static func headerRow() -> [String: XLSXCellValue] {
        var row: [String: XLSXCellValue] = [:]
        for column in ExcelChargingLogLayout.headerColumns {
            if let title = ExcelChargingLogLayout.headerTitles[column] {
                row[column] = .text(title)
            }
        }
        return row
    }

    private static func dataRow(for session: ChargingSession) -> [String: XLSXCellValue] {
        let startSerial = ExcelSerialDateParser.excelSerial(from: session.startDate)
        let totalEndDate = totalSessionEndDate(for: session)
        let endSerial = ExcelSerialDateParser.excelSerial(from: totalEndDate)
        let durationSeconds = session.sessionDuration > 0
            ? session.sessionDuration
            : max(0, Int(totalEndDate.timeIntervalSince(session.startDate)))

        var row: [String: XLSXCellValue] = [
            ExcelChargingLogLayout.Column.startDate: .number(startSerial),
            ExcelChargingLogLayout.Column.startTime: .number(startSerial),
            ExcelChargingLogLayout.Column.endDate: .number(endSerial),
            ExcelChargingLogLayout.Column.endTime: .number(endSerial),
            ExcelChargingLogLayout.Column.duration: .text(ExcelDurationParser.durationString(seconds: durationSeconds)),
            ExcelChargingLogLayout.Column.location: .text(session.chargingLocation)
        ]

        if session.startSOCPercent > 0 {
            row[ExcelChargingLogLayout.Column.startSOC] = .number(session.startSOCPercent)
        }
        if session.endSOCPercent > 0 {
            row[ExcelChargingLogLayout.Column.endSOC] = .number(session.endSOCPercent)
        }
        if session.odometerKM > 0 {
            row[ExcelChargingLogLayout.Column.odometer] = .number(session.odometerKM)
        }

        let chargerId = exportedChargerId(session.chargerId)
        if !chargerId.isEmpty {
            row[ExcelChargingLogLayout.Column.chargerId] = .text(chargerId)
        }
        if session.amountSGD > 0 {
            row[ExcelChargingLogLayout.Column.cost] = .number(session.amountSGD)
        }
        if session.energyKWh > 0 {
            row[ExcelChargingLogLayout.Column.energy] = .number(session.energyKWh)
        }

        if let reference = SessionImportMetadata.importReference(from: session.rawAIResponse)?.nilIfEmpty {
            row[ExcelChargingLogLayout.Column.reference] = .text(reference)
        }
        if !session.chargingNetwork.isEmpty, session.chargingNetwork != "Imported" {
            row[ExcelChargingLogLayout.Column.network] = .text(session.chargingNetwork)
        }
        if ChargerTypeOption.from(storedValue: session.chargerType) != .others {
            row[ExcelChargingLogLayout.Column.chargerType] = .text(session.chargerType)
        }
        if session.chargerPowerKW > 0 {
            row[ExcelChargingLogLayout.Column.powerKW] = .number(session.chargerPowerKW)
        }

        return row
    }

    private static func totalSessionEndDate(for session: ChargingSession) -> Date {
        if session.sessionDuration > 0 {
            return session.startDate.addingTimeInterval(TimeInterval(session.sessionDuration))
        }
        return session.endDate.addingTimeInterval(TimeInterval(max(0, session.idleDuration)))
    }

    private static func exportedChargerId(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.uppercased() == "UNKNOWN" {
            return ""
        }
        return trimmed
    }
}
