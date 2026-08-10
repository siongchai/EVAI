import Foundation

enum ExcelChargingLogLayout {
    enum Column {
        static let startDate = "A"
        static let startTime = "B"
        static let endDate = "C"
        static let endTime = "D"
        static let duration = "E"
        static let startSOC = "F"
        static let endSOC = "G"
        static let odometer = "H"
        static let location = "I"
        static let chargerId = "J"
        static let cost = "K"
        static let energy = "L"
        static let reference = "M"
        static let network = "N"
        static let chargerType = "O"
        static let powerKW = "P"
    }

    static let headerTitles: [String: String] = [
        Column.startDate: "Start Date",
        Column.startTime: "Start Time",
        Column.endDate: "End Date",
        Column.endTime: "End Time",
        Column.duration: "Duration",
        Column.startSOC: "Start SOC",
        Column.endSOC: "End SOC",
        Column.odometer: "Odometer",
        Column.location: "Charging Station",
        Column.chargerId: "Charging Station ID",
        Column.cost: "Cost",
        Column.energy: "Total Energy Consumption",
        Column.reference: "Reference",
        Column.network: "Network",
        Column.chargerType: "Charger Type",
        Column.powerKW: "Power kW"
    ]

    static let headerColumns: [String] = [
        Column.startDate, Column.startTime, Column.endDate, Column.endTime, Column.duration,
        Column.startSOC, Column.endSOC, Column.odometer, Column.location, Column.chargerId,
        Column.cost, Column.energy, Column.reference, Column.network, Column.chargerType, Column.powerKW
    ]

    static func isHeaderRow(_ cells: [String: String]) -> Bool {
        cells[Column.location] == headerTitles[Column.location]
            && cells[Column.startDate] == headerTitles[Column.startDate]
            && cells[Column.startTime] == headerTitles[Column.startTime]
            && cells[Column.endDate] == headerTitles[Column.endDate]
            && cells[Column.endTime] == headerTitles[Column.endTime]
            && (cells[Column.network] == nil || cells[Column.network] == headerTitles[Column.network])
            && (cells[Column.chargerType] == nil || cells[Column.chargerType] == headerTitles[Column.chargerType])
            && (cells[Column.powerKW] == nil || cells[Column.powerKW] == headerTitles[Column.powerKW])
    }
}
