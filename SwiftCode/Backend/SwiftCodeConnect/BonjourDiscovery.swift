import Foundation
import Network

public struct DiscoveredMacDevice: Identifiable, Equatable {
    public var id: String { name }
    public let name: String
    public let hostName: String
    public let port: UInt16
    public let endpoint: NWEndpoint
    public let discoveredDate: Date

    public init(name: String, hostName: String, port: UInt16, endpoint: NWEndpoint, discoveredDate: Date = Date()) {
        self.name = name
        self.hostName = hostName
        self.port = port
        self.endpoint = endpoint
        self.discoveredDate = discoveredDate
    }
}

@MainActor
public final class BonjourDiscovery: ObservableObject {
    public static let shared = BonjourDiscovery()

    @Published public private(set) var isSearching = false
    @Published public private(set) var discoveredDevices: [DiscoveredMacDevice] = []

    private var browser: NWBrowser?
    private let queue = DispatchQueue(label: "com.swiftcode.connect.discovery", qos: .userInitiated)

    private init() {}

    public func startDiscovery() {
        guard !isSearching else { return }
        discoveredDevices.removeAll()

        let descriptor = NWBrowser.Descriptor.bonjour(type: ConnectProtocolVersion.serviceType, domain: ConnectProtocolVersion.domain)
        let parameters = NWParameters.tcp
        let newBrowser = NWBrowser(for: descriptor, using: parameters)

        newBrowser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                switch state {
                case .ready:
                    self.isSearching = true
                case .failed(let error):
                    self.isSearching = false
                    print("[BonjourDiscovery] Browser failed with error: \(error)")
                case .cancelled:
                    self.isSearching = false
                default:
                    break
                }
            }
        }

        newBrowser.browseResultsChangedHandler = { [weak self] results, changes in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.handleBrowseResults(results)
            }
        }

        self.browser = newBrowser
        newBrowser.start(queue: queue)
        isSearching = true
    }

    public func stopDiscovery() {
        browser?.cancel()
        browser = nil
        isSearching = false
    }

    private func handleBrowseResults(_ results: Set<NWBrowser.Result>) {
        var devices: [DiscoveredMacDevice] = []

        for result in results {
            let name: String
            switch result.endpoint {
            case .service(let serviceName, _, _, _):
                name = serviceName
            case .hostPort(let host, let port):
                name = "\(host):\(port.rawValue)"
            default:
                name = "Unknown Mac"
            }

            var resolvedHost = "localhost"
            var resolvedPort: UInt16 = ConnectProtocolVersion.defaultPort

            if case let .hostPort(host, port) = result.endpoint {
                switch host {
                case .name(let hostName, _):
                    resolvedHost = hostName
                case .ipv4(let ip4):
                    resolvedHost = "\(ip4)"
                case .ipv6(let ip6):
                    resolvedHost = "[\(ip6)]"
                @unknown default:
                    break
                }
                resolvedPort = port.rawValue
            } else if case let .service(serviceName, _, _, _) = result.endpoint {
                resolvedHost = "\(serviceName).local"
            }

            let device = DiscoveredMacDevice(
                name: name,
                hostName: resolvedHost,
                port: resolvedPort,
                endpoint: result.endpoint
            )

            if !devices.contains(where: { $0.id == device.id }) {
                devices.append(device)
            }
        }

        self.discoveredDevices = devices
    }
}
