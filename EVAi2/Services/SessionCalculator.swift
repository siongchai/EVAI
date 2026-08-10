import Foundation

struct SessionComputedMetrics: Equatable {
    var costPerKWh: Double
    var sessionDurationMinutes: Int
    var socDelta: Double
    var efficiencyPercent: Double?

    static let empty = SessionComputedMetrics(
        costPerKWh: 0,
        sessionDurationMinutes: 0,
        socDelta: 0,
        efficiencyPercent: nil
    )
}

enum SessionCalculator {
    static func compute(from draft: EditableSessionDraft, batterySizeKWh: Double? = nil) -> SessionComputedMetrics {
        let energy   = Double(draft.energyKWh) ?? 0
        let amount   = Double(draft.amountSGD) ?? 0
        let startSOC = Double(draft.startSOCPercent) ?? 0
        let endSOC   = Double(draft.endSOCPercent) ?? 0

        let durationMinutes = chargingDurationMinutes(from: draft)
        let costPerKWh = energy > 0 ? amount / energy : 0
        let socDelta = endSOC - startSOC

        let efficiency: Double?
        if let batterySizeKWh, batterySizeKWh > 0, energy > 0 {
            efficiency = min(100, (energy / batterySizeKWh) * 100)
        } else if socDelta > 0 {
            efficiency = socDelta
        } else {
            efficiency = nil
        }

        return SessionComputedMetrics(
            costPerKWh: costPerKWh,
            sessionDurationMinutes: durationMinutes,
            socDelta: socDelta,
            efficiencyPercent: efficiency
        )
    }

    static func applyAutoCalculations(to draft: inout EditableSessionDraft, batterySizeKWh: Double? = nil) {
        syncEndDateFromDurations(&draft)

        guard draft.sessionDurationMinutes.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let charging = chargingDurationMinutes(from: draft)
        guard charging > 0 else { return }

        let idle = SessionDataParser.durationMinutesValue(from: draft.idleDurationMinutes)
        draft.sessionDurationMinutes = String(charging + idle)
    }

    /// Active charging end = start + (total session − idle).
    static func chargingEndDate(
        startDate: Date,
        totalSessionMinutes: Int,
        idleMinutes: Int
    ) -> Date? {
        let active = max(0, totalSessionMinutes - idleMinutes)
        guard active > 0 else { return nil }
        return startDate.addingTimeInterval(TimeInterval(active * 60))
    }

    static func syncEndDateFromDurations(_ draft: inout EditableSessionDraft) {
        let total = SessionDataParser.durationMinutesValue(from: draft.sessionDurationMinutes)
        guard total > 0 else { return }

        let idle = SessionDataParser.durationMinutesValue(from: draft.idleDurationMinutes)
        guard let chargingEnd = chargingEndDate(
            startDate: draft.startDate,
            totalSessionMinutes: total,
            idleMinutes: idle
        ) else { return }

        let calendar = Calendar.current
        if calendar.compare(chargingEnd, to: draft.endDate, toGranularity: .minute) != .orderedSame {
            draft.endDate = chargingEnd
        }
    }

    /// Active charging time in minutes: total session duration minus idle.
    static func chargingDurationMinutes(from draft: EditableSessionDraft) -> Int {
        let idleMins = SessionDataParser.durationMinutesValue(from: draft.idleDurationMinutes)

        let total = SessionDataParser.durationMinutesValue(from: draft.sessionDurationMinutes)
        if total > 0 {
            return max(0, total - idleMins)
        }

        var interval = draft.endDate.timeIntervalSince(draft.startDate)
        if interval < 0 { interval += 24 * 3600 }
        let minutes = Int(interval / 60)
        guard minutes > 0, minutes <= 1440 else { return 0 }
        return minutes
    }
}
