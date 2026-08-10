import Foundation

enum CaptureImageCategory: String, Codable {
    case sessionPhoto

    // Legacy values — decoded from older saved extractions only.
    case dashboardBefore
    case dashboardAfter
    case appScreenshot
    case receipt
    case chargerScreen

    static let uploadDefault: CaptureImageCategory = .sessionPhoto

    var title: String {
        switch self {
        case .sessionPhoto: "Session Photo"
        case .dashboardBefore: "Dashboard Before"
        case .dashboardAfter: "Dashboard After"
        case .appScreenshot: "App Summary"
        case .receipt: "Receipt"
        case .chargerScreen: "Charger Screen"
        }
    }

    var shortTitle: String {
        switch self {
        case .sessionPhoto: "Photo"
        case .dashboardBefore: "Before"
        case .dashboardAfter: "After"
        case .appScreenshot: "App"
        case .receipt: "Receipt"
        case .chargerScreen: "Charger"
        }
    }
}
