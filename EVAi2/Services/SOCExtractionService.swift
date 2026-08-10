import CoreGraphics
import Foundation

/// Shared SOC parsing and validation used by OCR heuristics, fusion, and post-processing.
enum SOCExtractionService {
    struct SectionReading: Equatable {
        let imageIndex: Int
        let soc: Double
        let timestamp: Date?
    }

    struct Pair: Equatable {
        let start: Double?
        let end: Double?
        let readings: [SectionReading]
    }

    /// km/h set-speed values commonly displayed without "%" on dashboards.
    private static let cruiseSpeedValues: Set<Int> = [
        20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95,
        100, 105, 110, 115, 120, 130
    ]

    // MARK: - Public

    /// Parse SOC readings from combined OCR text (section headers `--- Image N ---`).
    static func extractPair(from ocrText: String) -> Pair {
        pairFromReadings(extractSectionReadings(from: ocrText))
    }

    /// Spatially-aware SOC extraction directly from image Vision results.
    static func extractPairFromImages(_ images: [CaptureImageItem]) async -> Pair {
        var readings: [SectionReading] = []

        for (index, image) in images.enumerated() {
            let data = image.bestAvailableImageData()
            guard !data.isEmpty else { continue }

            let lines: [RecognizedTextLine]
            do {
                lines = try await VisionTextExtractionService.recognizeLines(in: data)
            } catch {
                continue
            }

            let sectionText = lines.map(\.text).joined(separator: "\n")
            guard !sectionText.isEmpty, !isNonDashboardSection(sectionText) else { continue }

            // Prefer spatially-scored reading; fall back to plain text scan.
            let soc = extractReading(from: lines) ?? bestSOCPercent(in: sectionText)
            guard let soc else { continue }

            readings.append(SectionReading(
                imageIndex: index + 1,
                soc: soc,
                timestamp: parseTimestamp(from: sectionText)
            ))
        }

        return pairFromReadings(readings)
    }

    /// Reconcile fused SOC values against on-device OCR evidence.
    ///
    /// Strategy:
    /// - Trust AI vision when it returns a valid, sensible pair (neither value is a cruise speed).
    ///   Cloud vision (GPT-4o / Claude) reads the actual pixels and is usually more accurate than OCR.
    /// - Use on-device OCR only to reject values that are clearly cruise/set-speed numbers,
    ///   or to fill in when AI returns nothing.
    static func reconcile(
        start: Double?,
        end: Double?,
        ocrText: String,
        imagePair: Pair? = nil
    ) -> (start: Double?, end: Double?, notes: [String]) {
        var notes: [String] = []

        // Report what on-device OCR found (for the debug panel).
        let textPair = extractPair(from: ocrText)
        let ocrPair  = chooseBestPair(textPair: textPair, imagePair: imagePair)

        if let s = ocrPair.start, let e = ocrPair.end, s != e {
            notes.append("On-device OCR found SOC: \(Int(s))% and \(Int(e))%.")
        } else if let s = ocrPair.start {
            notes.append("On-device OCR found one SOC reading: \(Int(s))%.")
        } else {
            notes.append("On-device OCR did not find battery % — relying on AI vision.")
        }

        // Determine whether each AI value is valid (not a cruise/set speed, in range 1–100).
        let startOK = start.map { isValidSOC($0) } ?? false
        let endOK   = end.map   { isValidSOC($0) } ?? false

        // Rule 1: AI gave us a complete, valid pair — trust it.
        // Cloud vision reads the actual pixels and typically outperforms on-device OCR for SOC.
        if startOK, endOK, let s = start, let e = end {
            let lo = min(s, e)
            let hi = max(s, e)
            if lo != hi {
                notes.append("AI vision SOC accepted: \(Int(lo))% → \(Int(hi))%.")
                return (lo, hi, notes)
            }
            // start == end: suspicious — fall through to check OCR
            notes.append("AI returned identical SOC for start and end (\(Int(s))%) — checking OCR.")
        }

        // Rule 2: AI has at least one cruise/set-speed value — reject those, keep any valid one.
        var resolvedStart = startOK ? start : nil
        var resolvedEnd   = endOK   ? end   : nil

        if !startOK, let s = start {
            notes.append("Rejected start SOC \(Int(s))% — cruise/set-speed value, not battery %.")
        }
        if !endOK, let e = end {
            notes.append("Rejected end SOC \(Int(e))% — cruise/set-speed value, not battery %.")
        }

        // Rule 3: Fill gaps from OCR (only values OCR found, regardless of AI confidence).
        if resolvedStart == nil, let ocrS = ocrPair.start, isValidSOC(ocrS) {
            resolvedStart = ocrS
            notes.append("Start SOC filled from on-device OCR: \(Int(ocrS))%.")
        }
        if resolvedEnd == nil, let ocrE = ocrPair.end, isValidSOC(ocrE) {
            resolvedEnd = ocrE
            notes.append("End SOC filled from on-device OCR: \(Int(ocrE))%.")
        }

        // Rule 4: Ensure start < end (charging raises battery level).
        if let s = resolvedStart, let e = resolvedEnd, s > e {
            resolvedStart = e
            resolvedEnd   = s
            notes.append("Start/End SOC swapped to match charging direction (start < end).")
        }

        return (resolvedStart, resolvedEnd, notes)
    }

    /// True when a value is a plausible battery SOC (1–100, not a typical cruise/set speed).
    static func isValidSOC(_ value: Double) -> Bool {
        let v = Int(value.rounded())
        return (1...100).contains(v) && !cruiseSpeedValues.contains(v)
    }

    // MARK: - Helpers (used externally by tests)

    static func isCruiseSpeed(_ value: Double) -> Bool {
        cruiseSpeedValues.contains(Int(value.rounded()))
    }

    static func isConfirmedInOCR(_ value: Double, ocrText: String) -> Bool {
        let intValue = Int(value.rounded())
        guard (0...100).contains(intValue) else { return false }
        for line in ocrText.components(separatedBy: .newlines) {
            if isBatteryPercentLine(line, value: intValue) { return true }
        }
        return false
    }

    static func isLikelyCruiseSpeed(_ value: Double, ocrText: String) -> Bool {
        isCruiseSpeed(value) && !isConfirmedInOCR(value, ocrText: ocrText)
    }

    // MARK: - Private

    private static func chooseBestPair(textPair: Pair, imagePair: Pair?) -> Pair {
        guard let imagePair else { return textPair }
        // Prefer whichever source gave us two distinct readings.
        if imagePair.readings.count >= 2,
           let s = imagePair.start, let e = imagePair.end, s != e {
            return imagePair
        }
        if textPair.readings.count >= 2,
           let s = textPair.start, let e = textPair.end, s != e {
            return textPair
        }
        // Fall back to whichever has more readings.
        return imagePair.readings.count >= textPair.readings.count ? imagePair : textPair
    }

    private static func pairFromReadings(_ readings: [SectionReading]) -> Pair {
        guard !readings.isEmpty else { return Pair(start: nil, end: nil, readings: []) }
        guard readings.count >= 2 else { return Pair(start: readings[0].soc, end: nil, readings: readings) }

        // Prefer timestamp ordering if available.
        let timed = readings.filter { $0.timestamp != nil }
        if timed.count >= 2 {
            let sorted = timed.sorted { ($0.timestamp!) < ($1.timestamp!) }
            if let first = sorted.first?.soc, let last = sorted.last?.soc, first != last {
                return Pair(start: first, end: last, readings: readings)
            }
        }

        // Fall back to SOC ordering.
        let bySOC = readings.sorted { $0.soc < $1.soc }
        if let lo = bySOC.first?.soc, let hi = bySOC.last?.soc, lo != hi {
            return Pair(start: lo, end: hi, readings: readings)
        }

        return Pair(start: readings[0].soc, end: nil, readings: readings)
    }

    private static func extractSectionReadings(from text: String) -> [SectionReading] {
        let sectionPattern = #"--- Image (\d+)(?:: [^\n]+)? ---"#
        guard let regex = try? NSRegularExpression(pattern: sectionPattern) else { return [] }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        var readings: [SectionReading] = []

        for (index, match) in matches.enumerated() {
            guard match.numberOfRanges > 1 else { continue }
            let sectionStart = match.range.location + match.range.length
            let sectionEnd = index + 1 < matches.count
                ? matches[index + 1].range.location
                : nsText.length
            let sectionText = nsText.substring(with: NSRange(location: sectionStart, length: sectionEnd - sectionStart))

            guard !isNonDashboardSection(sectionText),
                  let soc = bestSOCPercent(in: sectionText) else { continue }

            let imageNum = Int(nsText.substring(with: match.range(at: 1))) ?? index + 1
            readings.append(SectionReading(
                imageIndex: imageNum,
                soc: soc,
                timestamp: parseTimestamp(from: sectionText)
            ))
        }
        return readings
    }

    private static func extractReading(from lines: [RecognizedTextLine]) -> Double? {
        struct Candidate {
            let value: Double
            var score: Double
        }

        var candidates: [Candidate] = []

        for line in lines {
            let text = line.text
            let lower = text.lowercased()
            guard !isExcludedSOCLine(lower) else { continue }

            let value: Double?
            var baseScore = 0.0

            if let v = percentValue(in: text) {
                value = v
                baseScore += 3.0                         // explicit % symbol
            } else if let v = standaloneSOCValue(in: text) {
                value = v
                // Don't even score cruise-speed standalones.
                if cruiseSpeedValues.contains(Int(v.rounded())) { continue }
            } else {
                continue
            }

            guard let value else { continue }
            let intValue = Int(value.rounded())
            var score = baseScore + positionScore(for: line.boundingBox)

            if hasBatteryContext(lower)       { score += 3.0 }
            if text.count <= 5               { score += 1.0 }
            if cruiseSpeedValues.contains(intValue) {
                score -= 5.0
                if isCentralDisplay(line.boundingBox) { score -= 5.0 }
            }

            candidates.append(Candidate(value: value, score: score))
        }

        return candidates.max(by: { $0.score < $1.score })?.value
    }

    private static func bestSOCPercent(in text: String) -> Double? {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var percentCandidates: [Double] = []
        var bareCandidates:    [Double] = []

        for line in lines {
            let lower = line.lowercased()
            guard !isExcludedSOCLine(lower) else { continue }

            if let v = percentValue(in: line) {
                // Explicit % — only exclude if it's a cruise speed WITHOUT battery context.
                if !cruiseSpeedValues.contains(Int(v.rounded())) || hasBatteryContext(lower) {
                    percentCandidates.append(v)
                }
            } else if let v = standaloneSOCValue(in: line),
                      !cruiseSpeedValues.contains(Int(v.rounded())) {
                bareCandidates.append(v)
            }
        }

        if !percentCandidates.isEmpty {
            // Prefer a short standalone line (typical battery gauge readout).
            for line in lines {
                guard !isExcludedSOCLine(line.lowercased()) else { continue }
                if line.count <= 5, let v = percentValue(in: line),
                   !cruiseSpeedValues.contains(Int(v.rounded())) {
                    return v
                }
            }
            return percentCandidates.filter { !cruiseSpeedValues.contains(Int($0.rounded())) }.min()
                ?? percentCandidates.min()
        }

        return bareCandidates.min()
    }

    private static func isNonDashboardSection(_ text: String) -> Bool {
        let lower = text.lowercased()
        let appSignals = ["kwh", "total", "amount", "receipt", "pricing", "paid", "sgd", "$",
                          "charge+", "chargeplus", "session summary", "energy delivered", "grand total"]
        guard appSignals.contains(where: { lower.contains($0) }) else { return false }
        // Only exclude if there are no dashboard signals at all.
        let dashSignals = [
            text.range(of: #"\d{1,3}\s*%"#, options: .regularExpression) != nil,
            lower.contains("odo"),
            text.range(of: #"\d+\s*km"#, options: .regularExpression) != nil,
            text.range(of: #"(?i)\b\d{1,2}:\d{2}"#, options: .regularExpression) != nil
        ]
        return !dashSignals.contains(true)
    }

    private static func isBatteryPercentLine(_ line: String, value: Int) -> Bool {
        guard percentValue(in: line) == Double(value) else { return false }
        let lower = line.lowercased()
        if hasBatteryContext(lower) { return true }
        if cruiseSpeedValues.contains(value) { return false }
        return line.count <= 8
    }

    private static func hasBatteryContext(_ lower: String) -> Bool {
        lower.contains("soc") || lower.contains("battery") || lower.contains("charge")
    }

    private static func isExcludedSOCLine(_ lower: String) -> Bool {
        lower.contains("km/h") || lower.contains("kwh") || lower.contains("odo")
            || lower.contains("mileage") || lower.contains("°c")
            || lower.contains("total") || lower.contains("amount")
            || lower.contains("sgd") || lower.contains("$")
    }

    private static func standaloneSOCValue(in line: String) -> Double? {
        let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count <= 4, t.allSatisfy(\.isNumber) else { return nil }
        guard let v = Int(t), (1...100).contains(v) else { return nil }
        return Double(v)
    }

    private static func percentValue(in line: String) -> Double? {
        guard let match = firstCapture(in: line, pattern: #"(\d{1,3})\s*%"#),
              let v = Int(match), (1...100).contains(v) else { return nil }
        return Double(v)
    }

    private static func isCentralDisplay(_ box: CGRect) -> Bool {
        box.midX > 0.22 && box.midX < 0.78 && box.midY > 0.12 && box.midY < 0.62
    }

    private static func positionScore(for box: CGRect) -> Double {
        var score = 0.0
        if box.midY > 0.55             { score += 2.0 }
        if box.midX < 0.3 || box.midX > 0.7 { score += 1.5 }
        if isCentralDisplay(box)       { score -= 3.0 }
        return score
    }

    private static func parseTimestamp(from text: String) -> Date? {
        let patterns = [#"(?i)\b(\d{1,2}:\d{2}\s*(?:am|pm))\b"#, #"(?i)\b(\d{1,2}:\d{2})\b"#]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for pattern in patterns {
            guard let raw = firstCapture(in: text, pattern: pattern) else { continue }
            for fmt in ["h:mma", "h:mm a", "H:mm", "h:mm"] {
                formatter.dateFormat = fmt
                for attempt in [raw.replacingOccurrences(of: " ", with: ""), raw] {
                    if let date = formatter.date(from: attempt) { return date }
                }
            }
        }
        return nil
    }

    private static func firstCapture(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else { return nil }
        let value = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
