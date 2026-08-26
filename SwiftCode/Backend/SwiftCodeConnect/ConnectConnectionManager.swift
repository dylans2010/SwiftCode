import Foundation
import Combine
import UIKit

public enum MacConnectionState: Equatable {
    case disconnected
    case searching
    case pairing
    case connecting
    case authenticating
    case connected(PairedMacDevice)
    case reconnecting
    case failed(String)

    public var statusDescription: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .searching: return "Searching for Macs..."
        case .pairing: return "Pairing..."
        case .connecting: return "Connecting..."
        case .authenticating: return "Authenticating..."
        case .connected(let mac): return "Connected to \(mac.name)"
        case .reconnecting: return "Reconnecting..."
        case .failed(let message): return "Connection Failed: \(message)"
        }
    }

    public var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

@MainActor
public final class ConnectConnectionManager: ObservableObject {
    public static let shared = ConnectConnectionManager()

    @Published public private(set) var connectionState: MacConnectionState = .disconnected
    @Published public private(set) var activeConnectedMac: PairedMacDevice?

    public let trustStore = ConnectTrustStore.shared
    public let permissionManager = ConnectPermissionManager.shared
    public let discovery = BonjourDiscovery.shared

    private var activeTransport: WebSocketTransport?
    private var cancellables = Set<AnyCancellable>()
    private var autoReconnectTask: Task<Void, Never>?

    private init() {
        setupLifecycleObservers()
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
        if connectionState.isConnected {
            print("[ConnectConnectionManager] App backgrounded. Maintaining/graceful pause.")
        }
    }

    private func handleAppForegrounding() {
        if case .failed = connectionState {
            attemptAutoConnect()
        }
    }

    // MARK: - Connection Actions

    public func connect(to mac: PairedMacDevice) {
        guard let token = trustStore.getAuthToken(for: mac.id) else {
            connectionState = .failed("No authorization token stored for \(mac.name). Please pair again.")
            return
        }

        disconnect()
        connectionState = .connecting

        let host = mac.hostName.replacingOccurrences(of: ".local", with: "")
        let urlString = "ws://\(host):\(mac.port)/connect"
        guard let url = URL(string: urlString) else {
            connectionState = .failed("Invalid network endpoint URL for \(mac.name).")
            return
        }

        let transport = WebSocketTransport(url: url, authToken: token)
        transport.delegate = self
        self.activeTransport = transport
        self.activeConnectedMac = mac

        transport.connect()
        trustStore.updateLastSeen(for: mac.id)
    }

    public func disconnect() {
        autoReconnectTask?.cancel()
        autoReconnectTask = nil

        activeTransport?.disconnect()
        activeTransport = nil
        activeConnectedMac = nil
        connectionState = .disconnected
    }

    public func attemptAutoConnect() {
        guard !connectionState.isConnected else { return }
        guard let preferredMac = trustStore.pairedMacs.first(where: { $0.isAutoConnectEnabled }) ?? trustStore.pairedMacs.first else {
            return
        }
        connect(to: preferredMac)
    }

    public func sendEnvelope(_ envelope: ConnectMessageEnvelope) async throws {
        guard let transport = activeTransport, connectionState.isConnected else {
            throw ConnectProtocolError.deviceUnavailable
        }
        try await transport.send(envelope: envelope)
    }
}

// MARK: - WebSocketTransportDelegate

extension ConnectConnectionManager: WebSocketTransportDelegate {
    public func transport(_ transport: WebSocketTransport, didReceiveEnvelope envelope: ConnectMessageEnvelope) {
        Task { @MainActor in
            NotificationCenter.default.post(name: .connectEnvelopeReceived, object: envelope)
        }
    }

    public func transport(_ transport: WebSocketTransport, didChangeState state: TransportState) {
        Task { @MainActor in
            switch state {
            case .disconnected:
                if let mac = activeConnectedMac {
                    connectionState = .reconnecting
                    scheduleReconnection(for: mac)
                } else {
                    connectionState = .disconnected
                }
            case .connecting:
                connectionState = .connecting
            case .authenticating:
                connectionState = .authenticating
            case .connected:
                if let mac = activeConnectedMac {
                    connectionState = .connected(mac)
                }
            case .failed(let reason):
                connectionState = .failed(reason)
            }
        }
    }

    public func transport(_ transport: WebSocketTransport, didFailWithError error: Error) {
        Task { @MainActor in
            if let mac = activeConnectedMac {
                connectionState = .reconnecting
                scheduleReconnection(for: mac)
            } else {
                connectionState = .failed(error.localizedDescription)
            }
        }
    }

    private func scheduleReconnection(for mac: PairedMacDevice) {
        autoReconnectTask?.cancel()
        autoReconnectTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            self.connect(to: mac)
        }
    }
}

public extension Notification.Name {
    static let connectEnvelopeReceived = Notification.Name("com.swiftcode.connect.envelopeReceived")
}
