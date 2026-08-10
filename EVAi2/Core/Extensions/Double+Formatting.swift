import Foundation

extension Double {
    var currencyFormatted: String {
        String(format: "%@%.2f", AppConstants.currencySymbol, self)
    }

    var energyFormatted: String {
        String(format: "%.1f kWh", self)
    }

    var costPerKWhFormatted: String {
        String(format: "%@%.2f/kWh", AppConstants.currencySymbol, self)
    }

    var percentFormatted: String {
        String(format: "%.0f%%", self)
    }
}

extension Int {
    /// Formats a duration given in seconds as "1h 43m" or "30 min".
    var durationFormatted: String {
        guard self > 0 else { return "—" }
        let hours = self / 3600
        let minutes = (self % 3600) / 60
        return Self.formatHoursMinutes(hours: hours, minutes: minutes)
    }

    /// Formats a duration given in minutes as "1h 43m" or "30 min".
    var minutesDurationFormatted: String {
        guard self > 0 else { return "—" }
        return Self.formatHoursMinutes(hours: self / 60, minutes: self % 60)
    }

    private static func formatHoursMinutes(hours: Int, minutes: Int) -> String {
        if hours > 0 {
            if minutes > 0 {
                return "\(hours)h \(minutes)m"
            }
            return "\(hours)h"
        }
        return "\(minutes) min"
    }
}
