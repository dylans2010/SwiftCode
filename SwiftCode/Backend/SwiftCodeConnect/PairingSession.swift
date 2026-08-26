import Foundation
import Combine

public enum PairingState: Equatable {
    case idle
    case pairing
    case success(PairedMacDevice)
    case failed(String)
}

@MainActor
public final class PairingSession: ObservableObject {
    @Published public private(set) var state: PairingState = .idle

    private var transport: WebSocketTransport?
    private var targetMac: DiscoveredMacDevice?

    public init() {}

    public func generatePairingCode() -> String {
        let code = Int.random(in: 100000...999999)
        return String(code)
    }

    public func pair(with discoveredMac: DiscoveredMacDevice, pairingCode: String) async {
        state = .pairing
        self.targetMac = discoveredMac

        let rawHost = discoveredMac.hostName.replacingOccurrences(of: ".local", with: "")
        let safeHost = rawHost.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? rawHost
        let urlString = "ws://\(safeHost):\(discoveredMac.port)/connect"
        guard let url = URL(string: urlString) else {
            state = .failed("Invalid URL for Mac")
            return
        }

        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let deviceName = UIDevice.current.name

        let pairingRequest = PairingHandshakeRequest(
            deviceID: deviceID,
            deviceName: deviceName,
            pairingCode: pairingCode
        )

        do {
            let envelope = try ConnectMessageEnvelope.makeEnvelope(
                type: .pairRequest,
                payload: pairingRequest
            )

            let transport = WebSocketTransport(url: url)
            transport.delegate = self
            self.transport = transport
            transport.connect()

            // Sleep to allow socket connection to open
            try await Task.sleep(nanoseconds: 500_000_000)
            try await transport.send(envelope: envelope)
        } catch {
            state = .failed(error.localizedDescription)
            transport?.disconnect()
        }
    }

    public func handlePairingResponse(_ response: PairingHandshakeResponse) {
        guard let mac = targetMac else { return }
        if response.isSuccess, let token = response.authToken {
            let pairedMac = PairedMacDevice(
                id: response.macID.isEmpty ? mac.id : response.macID,
                name: response.macName.isEmpty ? mac.name : response.macName,
                hostName: mac.hostName,
                port: mac.port,
                datePaired: Date(),
                lastSeenDate: Date(),
                isAutoConnectEnabled: true
            )
            ConnectTrustStore.shared.savePairedMac(pairedMac, authToken: token)
            state = .success(pairedMac)
        } else {
            state = .failed(response.errorMessage ?? "Pairing was rejected by \(mac.name).")
        }
        transport?.disconnect()
    }

    public func cancel() {
        transport?.disconnect()
        transport = nil
        state = .idle
    }
}

extension PairingSession: WebSocketTransportDelegate {
    public func transport(_ transport: WebSocketTransport, didReceiveEnvelope envelope: ConnectMessageEnvelope) {
        Task { @MainActor in
            if envelope.type == .pairResponse {
                do {
                    let response = try envelope.decodePayload(PairingHandshakeResponse.self)
                    self.handlePairingResponse(response)
                } catch {
                    self.state = .failed("Invalid pairing response payload format.")
                }
            }
        }
    }

    public func transport(_ transport: WebSocketTransport, didChangeState state: TransportState) {
        Task { @MainActor in
            if case .failed(let err) = state {
                if self.state == .pairing {
                    self.state = .failed("Transport error during pairing: \(err)")
                }
            }
        }
    }

    public func transport(_ transport: WebSocketTransport, didFailWithError error: Error) {
        Task { @MainActor in
            if self.state == .pairing {
                self.state = .failed(error.localizedDescription)
            }
        }
    }
}
