import Foundation
import UIKit

enum ExportFormat: String, CaseIterable, Identifiable {
    case xlsx
    case json
    case pdf

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .xlsx: "Excel"
        case .json: "JSON"
        case .pdf: "PDF"
        }
    }

    var fileExtension: String {
        switch self {
        case .xlsx: "xlsx"
        case .pdf: "pdf"
        default: rawValue
        }
    }
}

enum ExportService {
    static func exportExcel(from sessions: [ChargingSession]) -> Data {
        ExcelExportService.exportWorkbook(from: sessions)
    }

    static func exportJSON(from sessions: [ChargingSession]) -> Data {
        let payload = sessions
            .sorted { $0.startDate > $1.startDate }
            .map { session in
                [
                    "id": session.id.uuidString,
                    "chargingLocation": session.chargingLocation,
                    "chargerId": session.chargerId,
                    "chargingNetwork": session.chargingNetwork,
                    "chargerType": session.chargerType,
                    "chargerPowerKW": session.chargerPowerKW,
                    "startDate": session.startDate.ISO8601Format(),
                    "endDate": session.endDate.ISO8601Format(),
                    "startSOCPercent": session.startSOCPercent,
                    "endSOCPercent": session.endSOCPercent,
                    "odometerKM": session.odometerKM,
                    "energyKWh": session.energyKWh,
                    "amountSGD": session.amountSGD,
                    "sessionDuration": session.sessionDuration,
                    "idleDuration": session.idleDuration,
                    "carModel": session.carModel,
                    "extractionConfidence": session.extractionConfidence,
                    "createdAt": session.createdAt.ISO8601Format(),
                    "updatedAt": session.updatedAt.ISO8601Format()
                ] as [String: Any]
            }

        let exportPayload: [String: Any] = [
            "app": AppConstants.appName,
            "exportedAt": Date.now.ISO8601Format(),
            "sessionCount": payload.count,
            "sessions": payload
        ]

        return (try? JSONSerialization.data(withJSONObject: exportPayload, options: [.prettyPrinted, .sortedKeys])) ?? Data()
    }

    static func exportPDF(from sessions: [ChargingSession]) -> Data {
        let sorted = sessions.sorted { $0.startDate > $1.startDate }
        let month = Date.now.startOfMonth
        let monthSessions = sorted.filter { $0.startDate.isSameMonth(as: month) }
        let totalCost = monthSessions.reduce(0) { $0 + $1.amountSGD }
        let totalEnergy = monthSessions.reduce(0) { $0 + $1.energyKWh }
        let insights = InsightEngine.generateInsights(from: sorted, month: month)
        let snapshot = SmartAnalyticsEngine.buildSnapshot(from: sorted, referenceMonth: month)

        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { context in
            context.beginPage()
            var y: CGFloat = 48

            func draw(_ text: String, font: UIFont, color: UIColor = .black) {
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                let height = text.boundingRect(
                    with: CGSize(width: pageRect.width - 96, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attrs,
                    context: nil
                ).height
                text.draw(in: CGRect(x: 48, y: y, width: pageRect.width - 96, height: height), withAttributes: attrs)
                y += height + 10
            }

            draw(AppConstants.appName, font: .boldSystemFont(ofSize: 24))
            draw("Charging Summary Report", font: .systemFont(ofSize: 14), color: .darkGray)
            draw("Generated \(Date.now.formatted(date: .abbreviated, time: .shortened))", font: .systemFont(ofSize: 11), color: .gray)

            y += 8
            draw("Overview", font: .boldSystemFont(ofSize: 16))
            draw("Total Sessions: \(sorted.count)", font: .systemFont(ofSize: 12))
            draw("This Month Cost: \(totalCost.currencyFormatted)", font: .systemFont(ofSize: 12))
            draw("This Month Energy: \(String(format: "%.1f kWh", totalEnergy))", font: .systemFont(ofSize: 12))
            draw("Forecast: \(snapshot.monthlyForecast.projectedMonthlyCost.currencyFormatted)", font: .systemFont(ofSize: 12))

            y += 8
            draw("Insights", font: .boldSystemFont(ofSize: 16))
            if insights.isEmpty {
                draw("No insights available.", font: .systemFont(ofSize: 12), color: .gray)
            } else {
                for insight in insights.prefix(5) {
                    draw("• \(insight.message)", font: .systemFont(ofSize: 12))
                }
            }

            y += 8
            draw("Recent Sessions", font: .boldSystemFont(ofSize: 16))
            for session in sorted.prefix(8) {
                let line = "\(session.startDate.dayMonthYearDisplay) · \(session.chargingLocation) · \(session.energyKWh.energyFormatted) · \(session.amountSGD.currencyFormatted)"
                draw(line, font: .systemFont(ofSize: 11))
                if y > pageRect.height - 60 {
                    context.beginPage()
                    y = 48
                }
            }
        }
    }

    static func exportData(format: ExportFormat, sessions: [ChargingSession]) -> Data {
        switch format {
        case .xlsx: exportExcel(from: sessions)
        case .json: exportJSON(from: sessions)
        case .pdf: exportPDF(from: sessions)
        }
    }

    static func fileNameDateStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: .now)
    }
}
