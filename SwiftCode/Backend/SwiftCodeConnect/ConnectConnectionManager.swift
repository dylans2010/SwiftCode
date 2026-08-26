import Foundation
import Network
import Combine
import UIKit
import os.log

public enum MacConnectionState: Equatable, Sendable {
    case idle
    case discovering
    case discovered(DiscoveredMacDevice)
    case connecting(String)
    case transportConnected
    case handshaking
    case authenticating
    case pairing
    case synchronizing
    case connected(PairedMacDevice)
    case reconnecting(Int)
    case connectionFailed(String)
    case authenticationFailed(String)
    case protocolMismatch(String)
    case portUnavailable(String)
    case hostUnavailable(String)
    case permissionDenied(String)

    public var statusDescription: String {
        switch self {
        case .idle:
            return "Idle"
        case .discovering:
            return "Searching for Macs…"
        case .discovered(let mac):
            return "Discovered \(mac.name)"
        case .connecting(let endpoint):
            return "Connecting to \(endpoint)…"
        case .transportConnected:
            return "Transport Connected"
        case .handshaking:
            return "Protocol Handshake…"
        case .authenticating:
            return "Authenticating…"
        case .pairing:
            return "Pairing in progress…"
        case .synchronizing:
            return "Synchronizing Workspace…"
        case .connected(let mac):
            return "Connected to \(mac.name)"
        case .reconnecting(let attempt):
            return "Reconnecting (Attempt \(attempt))…"
        case .connectionFailed(let message):
            return "Connection Refused: \(message)"
        case .authenticationFailed(let message):
            return "Authentication Failed: \(message)"
        case .protocolMismatch(let message):
            return "Protocol Mismatch: \(message)"
        case .portUnavailable(let message):
            return "Port Unavailable: \(message)"
        case .hostUnavailable(let message):
            return "Host Unreachable: \(message)"
        case .permissionDenied(let message):
            return "Permission Denied: \(message)"
        }
    }

    public var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    public var isConnecting: Bool {
        switch self {
        case .connecting, .transportConnected, .handshaking, .authenticating, .synchronizing, .reconnecting:
            return true
        default:
            return false
        }
    }
}

@MainActor
public final class ConnectConnectionManager: ObservableObject {
    public static let shared = ConnectConnectionManager()

    @Published public private(set) var connectionState: MacConnectionState = .idle
    @Published public private(set) var activeConnectedMac: PairedMacDevice?
    @Published public private(set) var lastErrorMessage: String?

    public let trustStore = ConnectTrustStore.shared
    public let permissionManager = ConnectPermissionManager.shared
    public let discovery = BonjourDiscovery.shared
    public let localListener = ConnectLocalListener.shared
    public let configManager = ConnectConfigurationManager.shared

    private var activeTransport: FramedTCPTransport?
    private var cancellables = Set<AnyCancellable>()
    private var reconnectAttempts = 0
    private var reconnectTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.swiftcode.connect", category: "ConnectConnectionManager")

    private init() {
        setupLifecycleObservers()
        // Automatically start local listener on configured port
        localListener.startListener()
    }

    // MARK: - Lifecycle & Network Monitoring

    private func setupLifecycleObservers() {
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleAppBackgrounding()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleAppForegrounding()
                }
            }
            .store(in: &cancellables)
    }

    private func handleAppBackgrounding() {
        logger.info("Application entering background state.")
    }

    private func handleAppForegrounding() {
        logger.info("Application returned to foreground.")
        if !localListener.isListening {
            localListener.startListener()
        }
        if case .connectionFailed = connectionState {
            attemptAutoConnect()
        }
    }

    // MARK: - Connection Flow

    public func connect(to mac: PairedMacDevice) {
        guard let token = trustStore.getAuthToken(for: mac.id) else {
            let err = "No authorization credentials stored for \(mac.name). Please pair again."
            connectionState = .authenticationFailed(err)
            lastErrorMessage = err
            return
        }

        disconnect(resetState: false)
        reconnectAttempts = 0

        // Check if Bonjour discovery has an updated IP/port for this Mac
        var targetHost = mac.hostName
        var targetPort = mac.port

        if let discovered = discovery.discoveredDevices.first(where: { $0.name == mac.name }) {
            targetHost = discovered.hostName
            targetPort = discovered.port
        }

        let cleanHost = targetHost.replacingOccurrences(of: ".local", with: "")
        connectionState = .connecting("\(cleanHost):\(targetPort)")
        lastErrorMessage = nil

        let transport = FramedTCPTransport(host: cleanHost, port: targetPort)
        transport.delegate = self
        self.activeTransport = transport
        self.activeConnectedMac = mac

        transport.connect()
        trustStore.updateLastSeen(for: mac.id)
    }

    public func connectManually(host: String, port: UInt16) {
        let cleanHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanHost.isEmpty, SwiftCodeConnectConfiguration.isValidPort(port) else {
            let err = "Invalid host '\(host)' or port '\(port)' specified."
            connectionState = .connectionFailed(err)
            lastErrorMessage = err
            return
        }

        configManager.updateManualEndpoint(host: cleanHost, port: port)

        // Find if already paired with a Mac at this host/name
        if let paired = trustStore.pairedMacs.first(where: { $0.hostName == cleanHost || $0.name.contains(cleanHost) }) {
            var updated = paired
            updated.hostName = cleanHost
            updated.port = port
            trustStore.savePairedMac(updated, authToken: trustStore.getAuthToken(for: paired.id) ?? "")
            connect(to: updated)
        } else {
            // Ephemeral connection attempt
            let manualDevice = PairedMacDevice(
                id: "manual-\(cleanHost)",
                name: "Mac (\(cleanHost))",
                hostName: cleanHost,
                port: port
            )
            connect(to: manualDevice)
        }
    }

    public func disconnect(resetState: Bool = true) {
        reconnectTask?.cancel()
        reconnectTask = nil

        activeTransport?.disconnect()
        activeTransport = nil

        if resetState {
            activeConnectedMac = nil
            connectionState = .idle
        }
    }

    public func attemptAutoConnect() {
        guard !connectionState.isConnected, !connectionState.isConnecting else { return }
        guard configManager.configuration.autoConnect else { return }

        guard let preferredMac = trustStore.pairedMacs.first(where: { $0.isAutoConnectEnabled }) ?? trustStore.pairedMacs.first else {
            return
        }
        connect(to: preferredMac)
    }

    public func sendEnvelope(_ envelope: MessageEnvelope) async throws {
        guard let transport = activeTransport, connectionState.isConnected else {
            throw ConnectProtocolError.deviceUnavailable
        }
        try await transport.send(envelope: envelope)
    }

    // MARK: - Post-Connection State Synchronization

    private func performPostAuthSynchronization(mac: PairedMacDevice) async {
        connectionState = .synchronizing

        do {
            // 1. Request Project Info
            let projectEnv = try MessageEnvelope.encode(
                payload: ["action": "get_active_project"],
                type: .projectRequest
            )
            try await activeTransport?.send(envelope: projectEnv)

            // 2. Request Git Status
            let gitEnv = try MessageEnvelope.encode(
                payload: ["action": "get_status"],
                type: .gitStatusRequest
            )
            try await activeTransport?.send(envelope: gitEnv)

            // 3. Request Device List
            let deviceEnv = try MessageEnvelope.encode(
                payload: ["action": "get_devices"],
                type: .deviceListRequest
            )
            try await activeTransport?.send(envelope: deviceEnv)

            self.connectionState = .connected(mac)
            self.logger.info("Successfully completed initial synchronization with \(mac.name)")
        } catch {
            self.logger.warning("Synchronization completed with partial queries: \(error.localizedDescription)")
            self.connectionState = .connected(mac)
        }
    }

    // MARK: - Reconnection Logic

    private func scheduleReconnection(for mac: PairedMacDevice) {
        guard configManager.configuration.autoConnect, reconnectAttempts < 5 else {
            return
        }

        reconnectAttempts += 1
        connectionState = .reconnecting(reconnectAttempts)

        let delaySeconds = Double(min(1 << reconnectAttempts, 16))

        reconnectTask?.cancel()
        reconnectTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }

            // Re-resolve target Mac endpoint via discovery if available
            if let latest = self.discovery.discoveredDevices.first(where: { $0.name == mac.name }) {
                var updated = mac
                updated.hostName = latest.hostName
                updated.port = latest.port
                self.connect(to: updated)
            } else {
                self.connect(to: mac)
            }
        }
    }
}

// MARK: - FramedTCPTransportDelegate

extension ConnectConnectionManager: FramedTCPTransportDelegate {
    public nonisolated func transport(_ transport: FramedTCPTransport, didReceiveEnvelope envelope: MessageEnvelope) {
        Task { @MainActor in
            NotificationCenter.default.post(name: .connectEnvelopeReceived, object: envelope)

            switch envelope.type {
            case .authResponse:
                if let authResp = try? envelope.decodePayload(ConnectAuthResponsePayload.self) {
                    if authResp.authenticated, let mac = self.activeConnectedMac {
                        await self.performPostAuthSynchronization(mac: mac)
                    } else {
                        let msg = "Authentication rejected by Mac. Token may have expired or been revoked."
                        self.connectionState = .authenticationFailed(msg)
                        self.lastErrorMessage = msg
                        self.disconnect(resetState: false)
                    }
                }

            case .pong:
                break

            case .errorResponse:
                if let errorPayload = try? envelope.decodePayload(ConnectErrorPayload.self) {
                    self.logger.error("Received protocol error from Mac: \(errorPayload.code) - \(errorPayload.message)")
                    if errorPayload.code == "PROTOCOL_MISMATCH" {
                        self.connectionState = .protocolMismatch(errorPayload.message)
                    }
                }

            default:
                break
            }
        }
    }

    public nonisolated func transport(_ transport: FramedTCPTransport, didChangeState state: TransportState) {
        Task { @MainActor in
            switch state {
            case .transportConnected:
                self.connectionState = .authenticating
                // Send authentication request
                if let mac = self.activeConnectedMac, let token = self.trustStore.getAuthToken(for: mac.id) {
                    let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
                    let authPayload = ConnectAuthRequestPayload(deviceID: deviceID, sessionToken: token)
                    if let authEnvelope = try? MessageEnvelope.encode(payload: authPayload, type: .authRequest) {
                        try? await transport.send(envelope: authEnvelope)
                    }
                }

            case .disconnected:
                if let mac = self.activeConnectedMac, self.connectionState.isConnected {
                    self.scheduleReconnection(for: mac)
                } else if !self.connectionState.isConnecting {
                    self.connectionState = .idle
                }

            case .failed(let protocolError):
                let errorMsg = protocolError.errorDescription ?? protocolError.localizedDescription
                self.lastErrorMessage = errorMsg

                switch protocolError {
                case .connectionRefused:
                    self.connectionState = .connectionFailed(errorMsg)
                case .timeout:
                    self.connectionState = .hostUnavailable(errorMsg)
                case .protocolMismatch:
                    self.connectionState = .protocolMismatch(errorMsg)
                case .portUnavailable:
                    self.connectionState = .portUnavailable(errorMsg)
                default:
                    self.connectionState = .connectionFailed(errorMsg)
                }

                if let mac = self.activeConnectedMac {
                    self.scheduleReconnection(for: mac)
                }

            default:
                break
            }
        }
    }

    public nonisolated func transport(_ transport: FramedTCPTransport, didFailWithError error: ConnectProtocolError) {
        Task { @MainActor in
            let errorMsg = error.errorDescription ?? error.localizedDescription
            self.lastErrorMessage = errorMsg

            if let mac = self.activeConnectedMac {
                self.scheduleReconnection(for: mac)
            } else {
                self.connectionState = .connectionFailed(errorMsg)
            }
        }
    }
}

public extension Notification.Name {
    static let connectEnvelopeReceived = Notification.Name("com.swiftcode.connect.envelopeReceived")
}
