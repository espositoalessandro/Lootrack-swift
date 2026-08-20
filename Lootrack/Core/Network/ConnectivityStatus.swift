import Dispatch
import Network
import Observation

nonisolated enum ConnectivityStatus: Equatable, Sendable {
    case unknown
    case offline
    case online
}

@MainActor
@Observable
final class NetworkMonitor {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.alessandroesposito.Lootrack.network-monitor")

    private(set) var status: ConnectivityStatus = .unknown

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let status: ConnectivityStatus = path.status == .satisfied ? .online : .offline

            Task { @MainActor [weak self] in
                self?.status = status
            }
        }

        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
