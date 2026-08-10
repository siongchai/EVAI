import Foundation

/// Parses charging session duration strings into whole minutes.
enum DurationParsingService {
    /// Maximum plausible duration when stored as plain minutes (not MMSS).
    private static let maxPlainMinutes = 720

    static func parseToMinutes(from value: String?) -> String {
        guard let value, !value.isEmpty else { return "" }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if let minutes = parseFormattedDuration(trimmed) {
            return String(minutes)
        }

        if let minutes = parseColonDuration(trimmed) {
            return String(minutes)
        }

        if let minutes = parsePlainNumericDuration(trimmed) {
            return String(minutes)
        }

        return ""
    }

    static func parseToMinutesValue(from value: String) -> Int {
        Int(parseToMinutes(from: value)) ?? 0
    }

    // MARK: - Formatted text (37 min 53 sec, 1h 43m, etc.)

    private static func parseFormattedDuration(_ value: String) -> Int? {
        let lower = value.lowercased()

        if let minutes = matchMinuteSecondText(in: lower) {
            return minutes
        }

        if lower.contains("h") {
            let noMin = lower
                .replacingOccurrences(of: "min", with: "")
                .replacingOccurrences(of: "minutes", with: "")
                .replacingOccurrences(of: "m", with: "")
            let sides = noMin.components(separatedBy: "h")
            let hours = Int(sides.first?.filter(\.isNumber) ?? "") ?? 0
            let mins = Int(sides.last?.filter(\.isNumber) ?? "") ?? 0
            let total = hours * 60 + mins
            return total > 0 ? total : nil
        }

        if lower.contains("min") || lower.hasSuffix("m") {
            let digits = lower.filter(\.isNumber)
            if let minutes = Int(digits), minutes > 0 {
                return minutes
            }
        }

        return nil
    }

    private static func matchMinuteSecondText(in lower: String) -> Int? {
        let patterns = [
            #"(?i)(\d+)\s*(?:min|mins|minute|minutes|m)\s*(\d+)\s*(?:sec|secs|second|seconds|s)"#,
            #"(?i)(\d+)\s*(?:min|mins|minute|minutes|m)\s*(\d+)\s*(?:sec|secs|second|seconds|s)?"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(
                    in: lower,
                    range: NSRange(lower.startIndex ..< lower.endIndex, in: lower)
                  ),
                  match.numberOfRanges >= 3,
                  let minutesRange = Range(match.range(at: 1), in: lower),
                  let secondsRange = Range(match.range(at: 2), in: lower),
                  let minutes = Int(lower[minutesRange]),
                  let seconds = Int(lower[secondsRange]),
                  minutes >= 0,
                  seconds >= 0,
                  seconds < 60 else {
                continue
            }
            return minutes
        }

        return nil
    }

    // MARK: - Colon-separated values

    private static func parseColonDuration(_ value: String) -> Int? {
        guard value.contains(":") else { return nil }

        let parts = value
            .split(separator: ":")
            .map { Int($0.filter(\.isNumber)) ?? -1 }
            .filter { $0 >= 0 }

        guard parts.count >= 2 else { return nil }

        if parts.count >= 3 {
            // HH:MM:SS — use hours and minutes, ignore seconds.
            return parts[0] * 60 + parts[1]
        }

        let first = parts[0]
        let second = parts[1]
        guard second < 60 else { return nil }

        let asHourMinute = first * 60 + second

        // 37:53 is almost certainly 37 min 53 sec, not 37 hours.
        if shouldTreatColonPairAsMinuteSecond(first: first, second: second, asHourMinute: asHourMinute) {
            return first
        }

        return asHourMinute > 0 ? asHourMinute : nil
    }

    private static func shouldTreatColonPairAsMinuteSecond(
        first: Int,
        second: Int,
        asHourMinute: Int
    ) -> Bool {
        if first >= 60 { return true }
        if first >= 24 { return true }
        if asHourMinute > maxPlainMinutes { return true }
        return false
    }

    // MARK: - Plain numbers (including AI MMSS mistakes like 3753)

    private static func parsePlainNumericDuration(_ value: String) -> Int? {
        let digitsOnly = value.filter(\.isNumber)
        guard let number = Int(digitsOnly), number > 0 else { return nil }

        if let minutes = decodeMinuteSecondConcatenation(number) {
            return minutes
        }

        guard number <= maxPlainMinutes else { return nil }
        return number
    }

    /// Detects values like 3753 meaning 37 minutes 53 seconds (not 3753 minutes).
    private static func decodeMinuteSecondConcatenation(_ value: Int) -> Int? {
        let text = String(value)
        guard text.count == 4 else { return nil }

        let minutes = value / 100
        let seconds = value % 100
        guard seconds < 60, minutes > 0, minutes <= maxPlainMinutes else { return nil }

        // Values this large are implausible as plain minutes for EV sessions.
        if value >= 1000 {
            return minutes
        }

        return nil
    }
}
