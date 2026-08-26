import Foundation
import Network
import os.log

public struct DiscoveredMacDevice: Identifiable, Equatable, Sendable {
    public var id: String { "\(name)-\(hostName):\(port)" }
    public let name: String
    public let hostName: String
    public let port: UInt16
    public let protocolVersion: String
    public let capabilities: [String]
    public let endpoint: NWEndpoint
    public let discoveredDate: Date

    public init(
        name: String,
        hostName: String,
        port: UInt16,
        protocolVersion: String = "1",
        capabilities: [String] = ["project", "build", "logs", "assist"],
        endpoint: NWEndpoint,
        discoveredDate: Date = Date()
    ) {
        self.name = name
        self.hostName = hostName
        self.port = port
        self.protocolVersion = protocolVersion
        self.capabilities = capabilities
        self.endpoint = endpoint
        self.discoveredDate = discoveredDate
    }

    public var formattedEndpoint: String {
        "\(hostName):\(port)"
    }
}

@MainActor
public final class BonjourDiscovery: ObservableObject {
    public static let shared = BonjourDiscovery()

    @Published public private(set) var isSearching = false
    @Published public private(set) var discoveredDevices: [DiscoveredMacDevice] = []
    @Published public private(set) var statusMessage: String = "Ready"

    private var browser: NWBrowser?
    private let queue = DispatchQueue(label: "com.swiftcode.connect.discovery", qos: .userInitiated)
    private let logger = Logger(subsystem: "com.swiftcode.connect", category: "BonjourDiscovery")

    private var activeResolvers: [String: NetService] = [:]

    private init() {}

    public func startDiscovery() {
        guard !isSearching else { return }
        discoveredDevices.removeAll()
        statusMessage = "Scanning for SwiftCode Macs…"

        let descriptor = NWBrowser.Descriptor.bonjour(
            type: ConnectProtocolVersion.serviceType,
            domain: ConnectProtocolVersion.domain
        )
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true

        let newBrowser = NWBrowser(for: descriptor, using: parameters)

        newBrowser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                switch state {
                case .ready:
                    self.isSearching = true
                    self.statusMessage = "Discovering on local network…"
                    self.logger.info("Bonjour browser ready and scanning")
                case .failed(let error):
                    self.isSearching = false
                    self.statusMessage = "Discovery failed: \(error.localizedDescription)"
                    self.logger.error("Bonjour browser failed: \(error.localizedDescription)")
                case .cancelled:
                    self.isSearching = false
                    self.statusMessage = "Discovery stopped"
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
        statusMessage = "Stopped"
        for (_, service) in activeResolvers {
            service.stop()
        }
        activeResolvers.removeAll()
    }

    private func handleBrowseResults(_ results: Set<NWBrowser.Result>) {
        var devices: [DiscoveredMacDevice] = []

        for result in results {
            var serviceName = "SwiftCode Mac"
            var domainName = "local."
            var resolvedPort: UInt16 = ConnectProtocolVersion.defaultPort
            var resolvedHost = "localhost"
            var protoVersion = "1"
            var capabilities = ["project", "build", "logs", "assist"]

            switch result.endpoint {
            case .service(let name, _, let domain, _):
                serviceName = name
                domainName = domain
                resolvedHost = "\(name).local"
            case .hostPort(let host, let port):
                switch host {
                case .name(let hostName, _):
                    resolvedHost = hostName
                    serviceName = hostName
                case .ipv4(let ip4):
                    resolvedHost = "\(ip4)"
                    serviceName = "Mac (\(ip4))"
                case .ipv6(let ip6):
                    resolvedHost = "[\(ip6)]"
                    serviceName = "Mac (\(ip6))"
                @unknown default:
                    break
                }
                resolvedPort = port.rawValue
            default:
                break
            }

            // Extract TXT record metadata if present
            if case let .bonjour(txtRecord) = result.metadata {
                let dict = txtRecord.dictionary
                if let name = dict["macName"], !name.isEmpty {
                    serviceName = name
                }
                if let proto = dict["proto"], !proto.isEmpty {
                    protoVersion = proto
                }
                if let caps = dict["caps"] {
                    capabilities = caps.components(separatedBy: ",")
                }
            }

            let initialDevice = DiscoveredMacDevice(
                name: serviceName,
                hostName: resolvedHost,
                port: resolvedPort,
                protocolVersion: protoVersion,
                capabilities: capabilities,
                endpoint: result.endpoint
            )

            devices.append(initialDevice)

            // Resolve actual IP address and port via NetService if needed
            if case let .service(name, type, domain, _) = result.endpoint {
                resolveServiceEndpoint(name: name, type: type, domain: domain, initialDevice: initialDevice)
            }
        }

        self.discoveredDevices = devices
    }

    private func resolveServiceEndpoint(name: String, type: String, domain: String, initialDevice: DiscoveredMacDevice) {
        let key = "\(name).\(type).\(domain)"
        if activeResolvers[key] != nil { return }

        let netService = NetService(domain: domain, type: type, name: name)
        let delegate = ServiceResolverDelegate { [weak self] resolvedHost, resolvedPort, txtDict in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.updateResolvedDevice(
                    originalName: initialDevice.name,
                    resolvedHost: resolvedHost,
                    resolvedPort: resolvedPort,
                    txtDict: txtDict,
                    endpoint: initialDevice.endpoint
                )
                self.activeResolvers.removeValue(forKey: key)
            }
        }

        // Retain delegate with service
        objc_setAssociatedObject(netService, "ResolverDelegate", delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        netService.delegate = delegate
        activeResolvers[key] = netService
        netService.resolve(withTimeout: 5.0)
    }

    private func updateResolvedDevice(
        originalName: String,
        resolvedHost: String?,
        resolvedPort: Int,
        txtDict: [String: String],
        endpoint: NWEndpoint
    ) {
        let targetPort = resolvedPort > 0 ? UInt16(resolvedPort) : ConnectProtocolVersion.defaultPort
        let targetHost = resolvedHost ?? "\(originalName).local"
        let macName = txtDict["macName"] ?? originalName
        let proto = txtDict["proto"] ?? "1"
        let caps = txtDict["caps"]?.components(separatedBy: ",") ?? ["project", "build", "logs", "assist"]

        let updatedDevice = DiscoveredMacDevice(
            name: macName,
            hostName: targetHost,
            port: targetPort,
            protocolVersion: proto,
            capabilities: caps,
            endpoint: endpoint
        )

        if let index = discoveredDevices.firstIndex(where: { $0.name == originalName || $0.hostName == targetHost }) {
            discoveredDevices[index] = updatedDevice
        } else {
            discoveredDevices.append(updatedDevice)
        }
    }
}

// MARK: - NetService Resolver Delegate

private final class ServiceResolverDelegate: NSObject, NetServiceDelegate, @unchecked Sendable {
    private let onResolved: @Sendable (String?, Int, [String: String]) -> Void

    init(onResolved: @escaping @Sendable (String?, Int, [String: String]) -> Void) {
        self.onResolved = onResolved
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        var resolvedHost: String? = sender.hostName
        let port = sender.port

        if let addresses = sender.addresses {
            for addressData in addresses {
                let address = addressData.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> String? in
                    guard let sockaddrPtr = ptr.baseAddress?.assumingMemoryBound(to: sockaddr.self) else { return nil }
                    var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    let socklen: socklen_t = sockaddrPtr.pointee.sa_family == sa_family_t(AF_INET) ? socklen_t(MemoryLayout<sockaddr_in>.size) : socklen_t(MemoryLayout<sockaddr_in6>.size)
                    if getnameinfo(sockaddrPtr, socklen, &hostBuffer, socklen_t(hostBuffer.count), nil, 0, NI_NUMERICHOST) == 0 {
                        return String(cString: hostBuffer)
                    }
                    return nil
                }
                if let address = address, !address.isEmpty, address != "127.0.0.1", address != "::1" {
                    resolvedHost = address
                    break
                }
            }
        }

        var txtDict: [String: String] = [:]
        if let data = sender.txtRecordData() {
            let dict = NetService.dictionary(fromTXTRecord: data)
            for (key, valData) in dict {
                if let str = String(data: valData, encoding: .utf8) {
                    txtDict[key] = str
                }
            }
        }

        onResolved(resolvedHost, port, txtDict)
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        onResolved(sender.hostName, sender.port, [:])
    }
}
