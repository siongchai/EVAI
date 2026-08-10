import Foundation

enum ExcelDurationParser {
    /// Parses EV charging log duration strings into seconds using hours and minutes only.
    /// Supports: "4 h 2 m 1 s", "52 m 14 s", "8h 1m", "8 h 55 m", and Excel day fractions (0.317…).
    /// Seconds in the source string are ignored.
    static func durationSeconds(from value: String) -> Int? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lower = trimmed.lowercased()
        if !lower.contains("h"), !lower.contains("m"), !lower.contains("s"), trimmed.contains(".") {
            if let serial = Double(trimmed), serial > 0, serial < 2 {
                let totalSeconds = Int((serial * 86_400).rounded())
                return truncateToWholeMinutes(totalSeconds)
            }
        }

        var hours = 0
        var minutes = 0

        if let match = firstMatch(in: lower, pattern: #"(\d+)\s*h"#) {
            hours = Int(match) ?? 0
        }
        if let match = firstMatch(in: lower, pattern: #"(\d+)\s*m(?:in)?(?:\s|$)"#) {
            minutes = Int(match) ?? 0
        } else if let match = firstMatch(in: lower, pattern: #"(\d+)\s*m"#) {
            minutes = Int(match) ?? 0
        }

        let total = hours * 3_600 + minutes * 60
        return total > 0 ? total : nil
    }

    static func truncateToWholeMinutes(_ seconds: Int) -> Int {
        guard seconds > 0 else { return 0 }
        return (seconds / 60) * 60
    }

    /// Formats duration to match the EV charging log Excel template (seconds included).
    static func durationString(seconds: Int) -> String {
        let total = max(0, seconds)
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let secs = total % 60
        return "\(hours) h \(minutes) m \(secs) s"
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex ..< text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let capture = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[capture])
    }
}

enum ExcelSerialDateParser {
    /// Excel date/time cells in the charging log represent Singapore local wall-clock times.
    private static var timeZone: TimeZone {
        TimeZone(identifier: "Asia/Singapore") ?? .current
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    static var testTimeZone: TimeZone { timeZone }

    static func date(fromExcelSerial value: String) -> Date? {
        guard let serial = Double(value.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        return date(fromExcelSerial: serial)
    }

    static func date(fromExcelSerial serial: Double) -> Date? {
        guard serial > 0 else { return nil }

        let dayIndex = Int(floor(serial))
        let fraction = serial - Double(dayIndex)
        let secondOfDay = min(max(0, Int((fraction * 86_400).rounded())), 86_399)

        guard let epoch = calendar.date(from: DateComponents(year: 1899, month: 12, day: 30)),
              let day = calendar.date(byAdding: .day, value: dayIndex, to: epoch) else {
            return nil
        }

        let startOfDay = calendar.startOfDay(for: day)
        return calendar.date(byAdding: .second, value: secondOfDay, to: startOfDay)
    }

    /// Combines an Excel date serial (column A/C) with a time serial (column B/D).
    /// The calendar day always comes from the date column; only the clock time comes from the time column.
    static func combinedDateTime(dateSerial: String, timeSerial: String) -> Date? {
        let trimmedDate = dateSerial.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTime = timeSerial.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let dateValue = Double(trimmedDate), dateValue > 0 else { return nil }
        let calendarDayIndex = Int(floor(dateValue))

        guard let timeValue = Double(trimmedTime), timeValue > 0 else {
            return date(fromExcelSerial: dateValue)
        }

        let timeFraction = timeOfDayFraction(from: timeValue)
        return date(fromDayIndex: calendarDayIndex, timeFraction: timeFraction)
    }

    /// Extracts the clock-time fraction from an Excel time cell, ignoring any embedded day index.
    static func timeOfDayFraction(from serial: Double) -> Double {
        if serial > 0, serial < 1 {
            return serial
        }
        return serial - floor(serial)
    }

    static func date(fromDayIndex dayIndex: Int, timeFraction: Double) -> Date? {
        guard dayIndex > 0 else { return nil }

        let clampedFraction = min(max(timeFraction, 0), 1)
        let secondOfDay = min(max(0, Int((clampedFraction * 86_400).rounded())), 86_399)

        guard let epoch = calendar.date(from: DateComponents(year: 1899, month: 12, day: 30)),
              let day = calendar.date(byAdding: .day, value: dayIndex, to: epoch) else {
            return nil
        }

        let startOfDay = calendar.startOfDay(for: day)
        return calendar.date(byAdding: .second, value: secondOfDay, to: startOfDay)
    }

    static func excelSerial(from date: Date) -> Double {
        guard let epoch = calendar.date(from: DateComponents(year: 1899, month: 12, day: 30)) else {
            return 0
        }

        let startOfDay = calendar.startOfDay(for: date)
        let dayIndex = calendar.dateComponents([.day], from: epoch, to: startOfDay).day ?? 0
        let secondOfDay = calendar.component(.hour, from: date) * 3_600
            + calendar.component(.minute, from: date) * 60
            + calendar.component(.second, from: date)
        let fraction = Double(secondOfDay) / 86_400
        return Double(dayIndex) + fraction
    }
}
