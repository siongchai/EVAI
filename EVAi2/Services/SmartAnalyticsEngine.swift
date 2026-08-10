import Foundation

enum SmartAnalyticsEngine {
    static func buildSnapshot(from sessions: [ChargingSession], referenceMonth: Date = .now.startOfMonth) -> SmartAnalyticsSnapshot {
        SmartAnalyticsSnapshot(
            bestNetwork: bestChargingNetwork(from: sessions),
            mostExpensiveStation: mostExpensiveStation(from: sessions),
            cheapestHour: cheapestChargingHour(from: sessions),
            networkCostAverages: averageCostPerKWhByNetwork(from: sessions),
            ninetyDayTrend: chargingTrendOver90Days(from: sessions),
            monthlyForecast: monthlyChargingForecast(from: sessions, referenceMonth: referenceMonth),
            costPrediction: costTrendPrediction(from: sessions),
            chargingHabits: batteryChargingHabitAnalysis(from: sessions)
        )
    }

    static func bestChargingNetwork(from sessions: [ChargingSession]) -> NetworkComparisonItem? {
        averageCostPerKWhByNetwork(from: sessions)
            .filter { $0.sessionCount >= 2 }
            .min(by: { $0.averageCostPerKWh < $1.averageCostPerKWh })
    }

    static func mostExpensiveStation(from sessions: [ChargingSession]) -> StationCostSummary? {
        let grouped = Dictionary(grouping: sessions.filter { !$0.chargingLocation.isEmpty }) { $0.chargingLocation }
        return grouped.map { location, items in
            let totalCost = items.reduce(0) { $0 + $1.amountSGD }
            let energy = items.reduce(0) { $0 + $1.energyKWh }
            return StationCostSummary(
                location: location,
                network: items.first?.chargingNetwork ?? "",
                totalCost: totalCost,
                sessionCount: items.count,
                averageCostPerKWh: energy > 0 ? totalCost / energy : 0
            )
        }
        .sorted { $0.averageCostPerKWh > $1.averageCostPerKWh }
        .first
    }

    static func cheapestChargingHour(from sessions: [ChargingSession]) -> HourlyCostSummary? {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) { calendar.component(.hour, from: $0.startDate) }

        return grouped.compactMap { hour, items -> HourlyCostSummary? in
            let energy = items.reduce(0) { $0 + $1.energyKWh }
            guard energy > 0 else { return nil }
            let cost = items.reduce(0) { $0 + $1.amountSGD }
            return HourlyCostSummary(
                hour: hour,
                averageCostPerKWh: cost / energy,
                sessionCount: items.count
            )
        }
        .filter { $0.sessionCount >= 2 }
        .min(by: { $0.averageCostPerKWh < $1.averageCostPerKWh })
    }

    static func averageCostPerKWhByNetwork(from sessions: [ChargingSession]) -> [NetworkComparisonItem] {
        let grouped = Dictionary(grouping: sessions.filter { !$0.chargingNetwork.isEmpty }) { $0.chargingNetwork }

        return grouped.map { network, items in
            let cost = items.reduce(0) { $0 + $1.amountSGD }
            let energy = items.reduce(0) { $0 + $1.energyKWh }
            return NetworkComparisonItem(
                network: network,
                averageCostPerKWh: energy > 0 ? cost / energy : 0,
                totalCost: cost,
                sessionCount: items.count
            )
        }
        .sorted { $0.averageCostPerKWh < $1.averageCostPerKWh }
    }

    static func chargingTrendOver90Days(from sessions: [ChargingSession]) -> [DailyTrendPoint] {
        let calendar = Calendar.current
        guard let start = calendar.date(byAdding: .day, value: -89, to: calendar.startOfDay(for: .now)) else {
            return []
        }

        let filtered = sessions.filter { $0.startDate >= start }
        let grouped = Dictionary(grouping: filtered) { calendar.startOfDay(for: $0.startDate) }

        return (0..<90).compactMap { offset -> DailyTrendPoint? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let daySessions = grouped[calendar.startOfDay(for: date)] ?? []
            return DailyTrendPoint(
                date: date,
                totalCost: daySessions.reduce(0) { $0 + $1.amountSGD },
                totalEnergy: daySessions.reduce(0) { $0 + $1.energyKWh }
            )
        }
    }

    static func monthlyChargingForecast(
        from sessions: [ChargingSession],
        referenceMonth: Date
    ) -> ChargingForecast {
        let calendar = Calendar.current
        let monthSessions = sessions.filter { $0.startDate.isSameMonth(as: referenceMonth) }
        let dayOfMonth = max(1, calendar.component(.day, from: .now))
        let daysInMonth = calendar.range(of: .day, in: .month, for: referenceMonth)?.count ?? 30

        let currentCost = monthSessions.reduce(0) { $0 + $1.amountSGD }
        let currentEnergy = monthSessions.reduce(0) { $0 + $1.energyKWh }
        let currentCount = monthSessions.count

        let scale = Double(daysInMonth) / Double(dayOfMonth)
        let projectedCost = currentCost * scale
        let projectedEnergy = currentEnergy * scale
        let projectedCount = Int((Double(currentCount) * scale).rounded())

        let previousMonth = calendar.date(byAdding: .month, value: -1, to: referenceMonth.startOfMonth) ?? referenceMonth
        let previousCost = sessions.filter { $0.startDate.isSameMonth(as: previousMonth) }
            .reduce(0) { $0 + $1.amountSGD }

        let direction: TrendDirection
        if previousCost <= 0 {
            direction = .stable
        } else if projectedCost > previousCost * 1.05 {
            direction = .up
        } else if projectedCost < previousCost * 0.95 {
            direction = .down
        } else {
            direction = .stable
        }

        return ChargingForecast(
            projectedMonthlyCost: projectedCost,
            projectedMonthlyEnergy: projectedEnergy,
            projectedSessionCount: projectedCount,
            trendDirection: direction
        )
    }

    static func costTrendPrediction(from sessions: [ChargingSession]) -> ChargingForecast {
        monthlyChargingForecast(from: sessions, referenceMonth: .now.startOfMonth)
    }

    static func batteryChargingHabitAnalysis(from sessions: [ChargingSession]) -> ChargingHabitSummary {
        let calendar = Calendar.current
        guard !sessions.isEmpty else {
            return ChargingHabitSummary(
                preferredHour: nil,
                preferredWeekday: nil,
                offPeakSessionRatio: 0,
                averageSessionsPerWeek: 0,
                lateNightSavingsPercent: nil
            )
        }

        let hourGrouped = Dictionary(grouping: sessions) { calendar.component(.hour, from: $0.startDate) }
        let preferredHour = hourGrouped.max(by: { $0.value.count < $1.value.count })?.key

        let weekdayGrouped = Dictionary(grouping: sessions) { calendar.component(.weekday, from: $0.startDate) }
        let preferredWeekday = weekdayGrouped.max(by: { $0.value.count < $1.value.count })?.key

        let offPeak = sessions.filter { calendar.component(.hour, from: $0.startDate) >= 22 || calendar.component(.hour, from: $0.startDate) < 7 }
        let offPeakRatio = Double(offPeak.count) / Double(sessions.count)

        let oldest = sessions.map(\.startDate).min() ?? .now
        let weeks = max(1, calendar.dateComponents([.weekOfYear], from: oldest, to: .now).weekOfYear ?? 1)
        let averagePerWeek = Double(sessions.count) / Double(weeks)

        let lateNight = sessions.filter { calendar.component(.hour, from: $0.startDate) >= 22 }
        let regular = sessions.filter { calendar.component(.hour, from: $0.startDate) < 22 }
        let lateAvg = averageCostPerKWh(for: lateNight)
        let regularAvg = averageCostPerKWh(for: regular)
        let savings: Double?
        if lateAvg > 0, regularAvg > 0, regularAvg > lateAvg {
            savings = ((regularAvg - lateAvg) / regularAvg) * 100
        } else {
            savings = nil
        }

        return ChargingHabitSummary(
            preferredHour: preferredHour,
            preferredWeekday: preferredWeekday,
            offPeakSessionRatio: offPeakRatio,
            averageSessionsPerWeek: averagePerWeek,
            lateNightSavingsPercent: savings
        )
    }

    static func quarterlyTrendPoints(from sessions: [ChargingSession], quarterCount: Int = 4) -> [QuarterlyTrendPoint] {
        let calendar = Calendar.current
        let anchor = quarterStart(for: .now, calendar: calendar)

        return (0..<quarterCount).reversed().compactMap { offset -> QuarterlyTrendPoint? in
            guard let quarterStart = calendar.date(byAdding: .month, value: -(offset * 3), to: anchor) else {
                return nil
            }
            let quarterEnd = calendar.date(byAdding: .month, value: 3, to: quarterStart) ?? quarterStart
            let quarterSessions = sessions.filter { $0.startDate >= quarterStart && $0.startDate < quarterEnd }
            let month = calendar.component(.month, from: quarterStart)
            let year = calendar.component(.year, from: quarterStart)
            let quarter = ((month - 1) / 3) + 1

            return QuarterlyTrendPoint(
                quarterStart: quarterStart,
                label: "Q\(quarter) \(year)",
                totalCost: quarterSessions.reduce(0) { $0 + $1.amountSGD },
                totalEnergy: quarterSessions.reduce(0) { $0 + $1.energyKWh },
                sessionCount: quarterSessions.count
            )
        }
    }

    static func sessionFrequencyHeatmap(from sessions: [ChargingSession]) -> [HeatmapCell] {
        let calendar = Calendar.current
        var cells: [HeatmapCell] = []

        for weekday in 1...7 {
            for hour in 0..<24 {
                let count = sessions.filter {
                    calendar.component(.weekday, from: $0.startDate) == weekday
                        && calendar.component(.hour, from: $0.startDate) == hour
                }.count
                cells.append(HeatmapCell(weekday: weekday, hour: hour, sessionCount: count))
            }
        }

        return cells
    }

    static func hourlyCostAnalysis(from sessions: [ChargingSession]) -> [HourlyCostSummary] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) { calendar.component(.hour, from: $0.startDate) }

        return (0..<24).compactMap { hour in
            let items = grouped[hour] ?? []
            let energy = items.reduce(0) { $0 + $1.energyKWh }
            guard energy > 0 else {
                return HourlyCostSummary(hour: hour, averageCostPerKWh: 0, sessionCount: items.count)
            }
            let cost = items.reduce(0) { $0 + $1.amountSGD }
            return HourlyCostSummary(hour: hour, averageCostPerKWh: cost / energy, sessionCount: items.count)
        }
    }

    static func socIncreaseTrend(from sessions: [ChargingSession], month: Date) -> [SOCTrendPoint] {
        let calendar = Calendar.current
        let filtered = sessions.filter { $0.startDate.isSameMonth(as: month) }
        let grouped = Dictionary(grouping: filtered) { calendar.component(.day, from: $0.startDate) }

        return grouped.keys.sorted().compactMap { day in
            guard let date = calendar.date(bySetting: .day, value: day, of: month.startOfMonth) else {
                return nil
            }
            let daySessions = grouped[day] ?? []
            let increases = daySessions.map { $0.endSOCPercent - $0.startSOCPercent }.filter { $0 > 0 }
            guard !increases.isEmpty else { return nil }
            return SOCTrendPoint(date: date, averageIncrease: increases.reduce(0, +) / Double(increases.count))
        }
    }

    static func batteryUsageTrend(from sessions: [ChargingSession], batterySizeKWh: Double?) -> [BatteryUsagePoint] {
        let calendar = Calendar.current
        let sorted = sessions.sorted { $0.startDate < $1.startDate }

        return sorted.map { session in
            let estimated: Double?
            if let batterySizeKWh, batterySizeKWh > 0 {
                estimated = (session.energyKWh / batterySizeKWh) * 100
            } else {
                estimated = session.endSOCPercent > session.startSOCPercent
                    ? session.endSOCPercent - session.startSOCPercent
                    : nil
            }
            return BatteryUsagePoint(
                date: calendar.startOfDay(for: session.startDate),
                energyKWh: session.energyKWh,
                estimatedBatteryPercent: estimated
            )
        }
    }

    private static func averageCostPerKWh(for sessions: [ChargingSession]) -> Double {
        let energy = sessions.reduce(0) { $0 + $1.energyKWh }
        let cost = sessions.reduce(0) { $0 + $1.amountSGD }
        guard energy > 0 else { return 0 }
        return cost / energy
    }

    private static func quarterStart(for date: Date, calendar: Calendar) -> Date {
        let month = calendar.component(.month, from: date)
        let year = calendar.component(.year, from: date)
        let quarterMonth = ((month - 1) / 3) * 3 + 1
        return calendar.date(from: DateComponents(year: year, month: quarterMonth, day: 1)) ?? date.startOfMonth
    }
}
