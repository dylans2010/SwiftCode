#if os(macOS)
import AppKit
import Foundation
import SwiftUI
import SwiftCodeConnect









@MainActor
final class HubConnectPeer {
    let device: DiscoveredIOSDevice
    private(set) var session: ConnectionSession?
    private(set) var deviceItems: [ConnectDeviceItem] = []
    private(set) var lastError: String?
    var onStateChange: (@MainActor (String) -> Void)?
    var onLogLine: (@MainActor (String) -> Void)?

    private var pending: [String: CheckedContinuation<MessageEnvelope, Error>] = [:]
    private var stateTask: Task<Void, Never>?

    
    
    private static var peersBySession: [UUID: HubConnectPeer] = [:]
    private static var handlersInstalled = false

    init(device: DiscoveredIOSDevice) {
        self.device = device
    }

    var isActive: Bool { session?.state == .active || session?.state == .connected }

    var stateText: String {
        guard let s = session else { return device.isAvailable ? "Discovered" : "Unavailable" }
        switch s.state {
        case .active, .connected: return "Connected"
        case .pairing: return "Pairing…"
        case .authenticating: return "Authenticating…"
        case .synchronizing: return "Synchronizing…"
        case .handshaking: return "Handshaking…"
        case .transportConnected: return "Connecting…"
        case .failed: return "Failed"
        case .disconnected: return "Disconnected"
        case .connecting, .idle, .discovering, .deviceDiscovered: return "Connecting…"
        }
    }

    

    
    
    private static let clientTypes: [ConnectMessageType] = [
        .handshakeResponse, .pairingResponse, .authResponse,
        .deviceListResponse, .screenCaptureResponse, .logEvent, .errorResponse,
    ]

    private static func installHandlers() {
        guard !handlersInstalled else { return }
        handlersInstalled = true
        for type in clientTypes {
            ConnectServer.shared.registerHandler(for: type) { envelope, session in
                HubConnectPeer.peersBySession[session.id]?.handle(envelope)
            }
        }
    }

    private func handle(_ envelope: MessageEnvelope) {
        if envelope.type == .logEvent {
            
            
            if let event = try? envelope.decodePayload(ConnectLogEventPayload.self) {
                let f = ISO8601DateFormatter()
                f.formatOptions = [.withInternetDateTime]
                onLogLine?("\(f.string(from: event.timestamp)) [\(event.level)] \(event.category): \(event.message)")
            }
            return
        }
        if let id = envelope.correlationID, let waiter = pending.removeValue(forKey: id) {
            if envelope.type == .errorResponse,
               let err = try? envelope.decodePayload(ConnectErrorPayload.self) {
                waiter.resume(throwing: err)
            } else {
                waiter.resume(returning: envelope)
            }
            return
        }
        
        if envelope.type == .handshakeResponse || envelope.type == .pairingResponse || envelope.type == .authResponse {
            onStateChange?(stateText)
        }
    }

    

    
    
    
    @discardableResult
    func connect(timeout: TimeInterval = 180) async -> Bool {
        Self.installHandlers()
        do {
            let session = try await ConnectServer.shared.connectToDevice(host: device.host, port: device.port)
            self.session = session
            Self.peersBySession[session.id] = self
            onStateChange?(stateText)
        } catch {
            lastError = error.localizedDescription
            onStateChange?(stateText)
            return false
        }
        
        
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if isActive {
                onStateChange?(stateText)
                _ = Task { await refreshDeviceList() }
                return true
            }
            if session?.state == .failed || session?.state == .disconnected { break }
            try? await Task.sleep(for: .milliseconds(400))
        }
        lastError = lastError ?? "The device did not finish pairing in time."
        onStateChange?(stateText)
        return isActive
    }

    func disconnect() {
        stateTask?.cancel()
        stateTask = nil
        if let s = session {
            Self.peersBySession.removeValue(forKey: s.id)
            s.disconnect()
        }
        session = nil
        onStateChange?(stateText)
    }

    deinit {
        
        let sid = session?.id
        if let sid { Task { @MainActor in Self.peersBySession.removeValue(forKey: sid) } }
    }

    

    
    @discardableResult
    func request<T: Encodable>(payload: T, type: ConnectMessageType,
                               timeout: TimeInterval = 20) async throws -> MessageEnvelope {
        guard let session, isActive else {
            throw ConnectErrorPayload(errorCode: .unauthorized, message: "The device is not connected.", details: nil)
        }
        let messageID = UUID().uuidString
        let envelope = try MessageEnvelope.encode(payload: payload, type: type, messageID: messageID)
        return try await withCheckedThrowingContinuation { continuation in
            pending[messageID] = continuation
            do {
                try session.send(envelope: envelope)
            } catch {
                pending.removeValue(forKey: messageID)
                continuation.resume(throwing: error)
            }
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(timeout))
                guard let self, let waiter = self.pending.removeValue(forKey: messageID) else { return }
                waiter.resume(throwing: ConnectErrorPayload(errorCode: .timeout,
                                                          message: "The device did not answer \(type.rawValue).", details: nil))
            }
        }
    }

    
    func refreshDeviceList() async {
        do {
            let env = try await request(payload: [String: String](), type: .deviceListRequest)
            let payload = try env.decodePayload(ConnectDeviceListResponsePayload.self)
            deviceItems = payload.devices
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        onStateChange?(stateText)
    }

    
    func subscribeLogs() async {
        _ = try? await request(payload: [String: String](), type: .logsSubscribeRequest)
    }

    func unsubscribeLogs() async {
        guard let session, isActive else { return }
        if let env = try? MessageEnvelope.encode(payload: [String: String](), type: .logsUnsubscribeRequest) {
            try? session.send(envelope: env)
        }
    }
}



struct HubNearbyDevicesView: View {
    @State private var discovery = IOSDiscoveryService.shared
    let hub: DevicesController
    @Environment(\.dismiss) private var dismiss
    @State private var busyID: String?
    @State private var statusLine = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Nearby Devices", systemImage: "dot.radiowaves.left.and.right")
                    .font(.headline)
                Spacer()
                if discovery.isScanning {
                    ProgressView().controlSize(.small)
                    Text("Scanning…").font(.caption).foregroundStyle(.secondary)
                } else {
                    Button("Scan Again") { discovery.refresh() }.controlSize(.small)
                }
            }
            Text("Devices running SwiftCode Connect appear here. Connecting pairs this Mac with the device; the device may ask for approval.")
                .font(.caption).foregroundStyle(.secondary)
            if discovery.discoveredDevices.isEmpty {
                ContentUnavailableView {
                    Label("No Devices Found", systemImage: "iphone.slash")
                } description: {
                    Text("Make sure the iPhone is on the same network and SwiftCode Connect is running on it.")
                }
                .frame(maxHeight: .infinity)
            } else {
                List(discovery.discoveredDevices) { d in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(d.name).font(.headline)
                            Text("\(d.deviceType) · \(d.endpointDisplay) · proto \(d.protocolVersion)")
                                .font(.caption).foregroundStyle(.secondary)
                            if let caps = d.capabilities.isEmpty ? nil : d.capabilities.joined(separator: ", ") {
                                Text(caps).font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                        Spacer()
                        if hub.isPairedConnectDevice(d.id) {
                            Button("Forget") { hub.forgetConnectDevice(d.id) }.controlSize(.small)
                        } else {
                            Button(busyID == d.id ? "Connecting…" : "Connect") {
                                connect(d)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(busyID != nil)
                        }
                    }
                }
            }
            if !statusLine.isEmpty {
                Text(statusLine).font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 520, height: 460)
        .onAppear { discovery.startScanning() }
        .onDisappear { discovery.stopScanning() }
    }

    private func connect(_ d: DiscoveredIOSDevice) {
        busyID = d.id
        statusLine = "Connecting to \(d.name)…"
        Task { @MainActor in
            let peer = HubConnectPeer(device: d)
            let ok = await peer.connect()
            busyID = nil
            if ok {
                hub.pairConnectDevice(peer)
                statusLine = "Connected to \(d.name)."
            } else {
                statusLine = peer.lastError ?? "Could not connect to \(d.name)."
            }
        }
    }
}
#endif
