import Foundation
import Network
import UIKit
import os.log

public enum ListenerStatus: Equatable, Sendable {
    case stopped
    case restarting(String)
    case binding(UInt16)
    case advertising(UInt16)
    case ready(UInt16)
    case failed(String)

    public var statusDescription: String {
        switch self {
        case .stopped:
            return "Stopped"
        case .restarting(let msg):
            return msg
        case .binding(let port):
            return "Binding port \(port)…"
        case .advertising(let port):
            return "Advertising endpoint on port \(port)…"
        case .ready(let port):
            return "Listening on port \(port)"
        case .failed(let err):
            return "Listener error: \(err)"
        }
    }

    public var isReady: Bool {
        if case .ready = self { return true }
        return false
    }
}

@MainActor
public final class ConnectLocalListener: ObservableObject {
    public static let shared = ConnectLocalListener()

    @Published public private(set) var status: ListenerStatus = .stopped
    @Published public private(set) var boundPort: UInt16?
    @Published public private(set) var isListening: Bool = false
    @Published public private(set) var isAdvertising: Bool = false
    @Published public private(set) var errorMessage: String?

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.swiftcode.connect.listener", qos: .userInitiated)
    private let logger = Logger(subsystem: "com.swiftcode.connect", category: "ConnectLocalListener")

    private init() {}

    /// Starts the local listener using the port from configuration.
    public func startListener(port: UInt16? = nil) {
        let targetPort = port ?? ConnectConfigurationManager.shared.configuration.port
        guard SwiftCodeConnectConfiguration.isValidPort(targetPort) else {
            let errorMsg = "Port \(targetPort) is outside the valid range (1024-65535)."
            self.status = .failed(errorMsg)
            self.errorMessage = errorMsg
            return
        }

        stopListener()

        self.status = .binding(targetPort)
        self.errorMessage = nil

        do {
            guard let nwPort = NWEndpoint.Port(rawValue: targetPort) else {
                throw ConnectProtocolError.portUnavailable
            }

            let tcpOptions = NWProtocolTCP.Options()
            tcpOptions.enableKeepalive = true

            let parameters = NWParameters(tls: nil, tcp: tcpOptions)
            parameters.includePeerToPeer = true
            parameters.allowLocalEndpointReuse = true

            let newListener = try NWListener(using: parameters, on: nwPort)

            // Configure Bonjour Service Discovery Metadata
            let deviceName = UIDevice.current.name
            let txtRecord = NWTXTRecord([
                "txtvers": "1",
                "proto": "\(ConnectProtocolVersion.current)",
                "deviceName": deviceName,
                "deviceType": "ios",
                "appVers": "1.0",
                "caps": "project,build,logs,assist"
            ])

            if ConnectConfigurationManager.shared.configuration.advertiseService {
                newListener.service = NWListener.Service(
                    name: deviceName,
                    type: ConnectProtocolVersion.serviceType,
                    domain: nil,
                    txtRecord: txtRecord
                )
            }

            newListener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    switch state {
                    case .ready:
                        if let assignedPort = newListener.port?.rawValue {
                            self.boundPort = assignedPort
                            self.isListening = true
                            self.isAdvertising = ConnectConfigurationManager.shared.configuration.advertiseService
                            self.status = .ready(assignedPort)
                            self.logger.info("SwiftCode iOS listener successfully bound on port \(assignedPort)")
                        }
                    case .failed(let error):
                        self.logger.error("SwiftCode iOS listener failed: \(error.localizedDescription)")
                        let userFriendlyMessage: String
                        switch error {
                        case .posix(let code) where code == .EADDRINUSE:
                            userFriendlyMessage = "Port \(targetPort) is already being used by another service. Choose another port."
                        default:
                            userFriendlyMessage = "Failed to bind to port \(targetPort): \(error.localizedDescription)"
                        }
                        self.isListening = false
                        self.isAdvertising = false
                        self.boundPort = nil
                        self.errorMessage = userFriendlyMessage
                        self.status = .failed(userFriendlyMessage)
                        self.stopListener()
                    case .cancelled:
                        self.isListening = false
                        self.isAdvertising = false
                        self.boundPort = nil
                        self.status = .stopped
                    default:
                        break
                    }
                }
            }

            newListener.newConnectionHandler = { connection in
                // Handle incoming connection from Mac if initiated remotely
                connection.cancel()
            }

            self.listener = newListener
            newListener.start(queue: queue)

        } catch {
            let errorMsg = "Could not initialize local listener on port \(targetPort): \(error.localizedDescription)"
            self.logger.error("\(errorMsg)")
            self.status = .failed(errorMsg)
            self.errorMessage = errorMsg
            self.isListening = false
            self.isAdvertising = false
        }
    }

    /// Changes the listening port with step-by-step state progression and commits to configuration upon success.
    public func changePort(to newPort: UInt16) async -> Bool {
        guard SwiftCodeConnectConfiguration.isValidPort(newPort) else {
            self.errorMessage = "Port \(newPort) is invalid. Must be between 1024 and 65535."
            self.status = .failed(self.errorMessage!)
            return false
        }

        self.status = .restarting("Restarting SwiftCode Connect…")
        try? await Task.sleep(nanoseconds: 300_000_000)

        self.status = .binding(newPort)
        try? await Task.sleep(nanoseconds: 300_000_000)

        startListener(port: newPort)

        // Allow listener to enter ready or failed state
        for _ in 0..<10 {
            try? await Task.sleep(nanoseconds: 200_000_000)
            if case .ready(let port) = status, port == newPort {
                ConnectConfigurationManager.shared.updatePort(newPort)
                self.status = .ready(newPort)
                return true
            }
            if case .failed = status {
                return false
            }
        }

        return isListening
    }

    public func stopListener() {
        listener?.cancel()
        listener = nil
        isListening = false
        isAdvertising = false
        boundPort = nil
        if status != .stopped && !status.statusDescription.contains("Failed") {
            status = .stopped
        }
    }
}
