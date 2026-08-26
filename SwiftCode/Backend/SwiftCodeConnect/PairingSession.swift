import Foundation
import Network
import Combine
import UIKit
import os.log

public enum PairingState: Equatable, Sendable {
    case idle
    case pairing
    case success(PairedMacDevice)
    case failed(String)
}

@MainActor
public final class PairingSession: ObservableObject {
    public static let shared = PairingSession()

    @Published public private(set) var state: PairingState = .idle
    @Published public private(set) var currentPairingCode: String = ""

    private var transport: FramedTCPTransport?
    private var targetMac: DiscoveredMacDevice?
    private let logger = Logger(subsystem: "com.swiftcode.connect", category: "PairingSession")

    public init() {}

    public func generatePairingCode() -> String {
        let code = Int.random(in: 100000...999999)
        let formatted = String(code)
        self.currentPairingCode = formatted
        return formatted
    }

    public func pair(with discoveredMac: DiscoveredMacDevice, pairingCode: String) async {
        state = .pairing
        self.targetMac = discoveredMac
        self.currentPairingCode = pairingCode

        let transport = FramedTCPTransport(
            endpoint: discoveredMac.endpoint,
            hostDescription: discoveredMac.hostName,
            port: discoveredMac.port
        )
        transport.delegate = self
        self.transport = transport
        transport.connect()

        // Wait briefly for socket readiness or timeout
        for _ in 0..<15 {
            try? await Task.sleep(nanoseconds: 200_000_000)
            if transport.state == .transportConnected {
                break
            }
            if case .failed(let err) = transport.state {
                state = .failed(err.errorDescription ?? "Failed to connect to \(discoveredMac.name).")
                transport.disconnect()
                return
            }
        }

        guard transport.state == .transportConnected else {
            state = .failed("Connection timed out while reaching \(discoveredMac.name) on port \(discoveredMac.port).")
            transport.disconnect()
            return
        }

        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let deviceName = UIDevice.current.name

        let payload = ConnectPairingRequestPayload(
            deviceID: deviceID,
            deviceName: deviceName,
            deviceModel: "iPhone",
            clientVersion: "1.0",
            publicKeyPem: "",
            verificationCode: pairingCode
        )

        do {
            let envelope = try MessageEnvelope.encode(
                payload: payload,
                type: .pairingRequest
            )
            try await transport.send(envelope: envelope)
            logger.info("Sent pairing request with code \(pairingCode) to \(discoveredMac.name)")
        } catch {
            state = .failed("Failed to send pairing request: \(error.localizedDescription)")
            transport.disconnect()
        }
    }

    public func pairManually(host: String, port: UInt16, pairingCode: String) async {
        let dummyEndpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port) ?? NWEndpoint.Port(rawValue: ConnectProtocolVersion.defaultPort)!
        )
        let manualMac = DiscoveredMacDevice(
            name: "Mac (\(host))",
            hostName: host,
            port: port,
            endpoint: dummyEndpoint
        )
        await pair(with: manualMac, pairingCode: pairingCode)
    }

    public func handlePairingResponse(_ response: ConnectPairingResponsePayload) {
        guard let mac = targetMac else { return }

        if response.approved, let token = response.sessionToken {
            let pairedMac = PairedMacDevice(
                id: response.macName.isEmpty ? mac.id : response.macName,
                name: response.macName.isEmpty ? mac.name : response.macName,
                hostName: mac.hostName,
                port: mac.port,
                datePaired: Date(),
                lastSeenDate: Date(),
                isAutoConnectEnabled: true
            )
            ConnectTrustStore.shared.savePairedMac(pairedMac, authToken: token)
            state = .success(pairedMac)
            logger.info("Successfully paired with \(pairedMac.name)")
        } else {
            state = .failed("Pairing was rejected or cancelled on \(mac.name).")
        }
        transport?.disconnect()
    }

    public func cancel() {
        transport?.disconnect()
        transport = nil
        targetMac = nil
        state = .idle
    }
}

extension PairingSession: FramedTCPTransportDelegate {
    public nonisolated func transport(_ transport: FramedTCPTransport, didReceiveEnvelope envelope: MessageEnvelope) {
        Task { @MainActor in
            if envelope.type == .pairingResponse {
                do {
                    let response = try envelope.decodePayload(ConnectPairingResponsePayload.self)
                    self.handlePairingResponse(response)
                } catch {
                    self.state = .failed("Invalid pairing response payload format.")
                }
            }
        }
    }

    public nonisolated func transport(_ transport: FramedTCPTransport, didChangeState state: TransportState) {
        Task { @MainActor in
            if case .failed(let err) = state {
                if self.state == .pairing {
                    self.state = .failed("Transport error during pairing: \(err.errorDescription ?? err.localizedDescription)")
                }
            }
        }
    }

    public nonisolated func transport(_ transport: FramedTCPTransport, didFailWithError error: ConnectProtocolError) {
        Task { @MainActor in
            if self.state == .pairing {
                self.state = .failed(error.errorDescription ?? error.localizedDescription)
            }
        }
    }
}
