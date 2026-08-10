import Foundation
import Network
import Observation

@Observable
@MainActor
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    private(set) var isConnected = true
    private(set) var isExpensive = false
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "sg.tsc.EVAi2.network-monitor")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                self?.isExpensive = path.isExpensive
            }
        }
        monitor.start(queue: queue)
    }

    var requiresOnlineExtraction: Bool {
        !isConnected
    }
}
