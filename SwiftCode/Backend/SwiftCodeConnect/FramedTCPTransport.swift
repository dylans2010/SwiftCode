import Foundation
import Network
import os.log

public enum TransportState: Equatable, Sendable {
    case disconnected
    case connecting
    case transportConnected
    case authenticating
    case connected
    case failed(ConnectProtocolError)

    public var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

public protocol FramedTCPTransportDelegate: AnyObject {
    func transport(_ transport: FramedTCPTransport, didReceiveEnvelope envelope: MessageEnvelope)
    func transport(_ transport: FramedTCPTransport, didChangeState state: TransportState)
    func transport(_ transport: FramedTCPTransport, didFailWithError error: ConnectProtocolError)
}

/// Raw TCP Transport utilizing Apple's Network.framework with 4-byte big-endian length prefix framing.
/// Perfectly interoperable with SwiftCode macOS ConnectServer.
public final class FramedTCPTransport: @unchecked Sendable {
    public private(set) var state: TransportState = .disconnected {
        didSet {
            delegate?.transport(self, didChangeState: state)
        }
    }

    public weak var delegate: FramedTCPTransportDelegate?

    public let targetEndpoint: NWEndpoint
    public let targetHostDescription: String
    public let targetPort: UInt16

    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.swiftcode.connect.transport", qos: .userInitiated)
    private let logger = Logger(subsystem: "com.swiftcode.connect", category: "FramedTCPTransport")
    private var isCancelled = false

    public init(endpoint: NWEndpoint, hostDescription: String, port: UInt16) {
        self.targetEndpoint = endpoint
        self.targetHostDescription = hostDescription
        self.targetPort = port
    }

    public convenience init(host: String, port: UInt16) {
        let nwHost = NWEndpoint.Host(host)
        let nwPort = NWEndpoint.Port(rawValue: port) ?? NWEndpoint.Port(rawValue: ConnectProtocolVersion.defaultPort)!
        let endpoint = NWEndpoint.hostPort(host: nwHost, port: nwPort)
        self.init(endpoint: endpoint, hostDescription: host, port: port)
    }

    public func connect() {
        guard state == .disconnected || !state.isConnected else { return }

        isCancelled = false
        state = .connecting

        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.enableKeepalive = true
        tcpOptions.keepaliveIdle = 10
        tcpOptions.keepaliveInterval = 5
        tcpOptions.keepaliveCount = 3

        let params = NWParameters(tls: nil, tcp: tcpOptions)
        params.includePeerToPeer = true

        let newConnection = NWConnection(to: targetEndpoint, using: params)
        self.connection = newConnection

        newConnection.stateUpdateHandler = { [weak self] connectionState in
            guard let self = self, !self.isCancelled else { return }

            switch connectionState {
            case .ready:
                self.logger.info("TCP socket connected to \(self.targetHostDescription):\(self.targetPort)")
                self.state = .transportConnected
                self.receiveNextFrame()
            case .failed(let nwError):
                self.logger.error("TCP connection failed: \(nwError.localizedDescription)")
                let protocolError: ConnectProtocolError
                switch nwError {
                case .posix(let code) where code == .ECONNREFUSED:
                    protocolError = .connectionRefused
                case .posix(let code) where code == .ETIMEDOUT:
                    protocolError = .timeout
                case .posix(let code) where code == .EHOSTUNREACH:
                    protocolError = .hostUnavailable
                case .dns:
                    protocolError = .bonjourMismatch
                default:
                    protocolError = .deviceUnavailable
                }
                self.state = .failed(protocolError)
                self.delegate?.transport(self, didFailWithError: protocolError)
                self.disconnect()
            case .cancelled:
                self.state = .disconnected
            case .waiting(let nwError):
                self.logger.warning("TCP connection waiting: \(nwError.localizedDescription)")
            default:
                break
            }
        }

        newConnection.start(queue: queue)
    }

    public func updateState(_ newState: TransportState) {
        self.state = newState
    }

    public func disconnect() {
        isCancelled = true
        connection?.cancel()
        connection = nil
        if state != .disconnected {
            state = .disconnected
        }
    }

    public func send(envelope: MessageEnvelope) async throws {
        guard let connection = connection, state != .disconnected else {
            throw ConnectProtocolError.deviceUnavailable
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let payloadData = try encoder.encode(envelope)

        var length = UInt32(payloadData.count).bigEndian
        var packetData = Data(bytes: &length, count: 4)
        packetData.append(payloadData)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: packetData, completion: .contentProcessed({ error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }))
        }
    }

    private func receiveNextFrame() {
        guard let connection = connection, !isCancelled else { return }

        // Read 4-byte big-endian frame header length
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] data, context, isComplete, error in
            guard let self = self, !self.isCancelled else { return }

            if let error = error {
                self.logger.error("Error receiving frame header: \(error.localizedDescription)")
                self.state = .disconnected
                return
            }

            guard let data = data, data.count == 4 else {
                if isComplete {
                    self.logger.info("Connection closed by peer.")
                    self.state = .disconnected
                }
                return
            }

            let length = data.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            guard length > 0, length < 50_000_000 else {
                self.logger.error("Invalid packet length received: \(length)")
                self.state = .failed(.invalidPayload)
                return
            }

            // Read the body of specified length
            self.connection?.receive(minimumIncompleteLength: Int(length), maximumLength: Int(length)) { [weak self] bodyData, bodyContext, bodyIsComplete, bodyError in
                guard let self = self, !self.isCancelled else { return }

                if let bodyError = bodyError {
                    self.logger.error("Error receiving frame body: \(bodyError.localizedDescription)")
                    self.state = .disconnected
                    return
                }

                guard let bodyData = bodyData, bodyData.count == Int(length) else {
                    self.state = .failed(.invalidPayload)
                    return
                }

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601

                do {
                    let envelope = try decoder.decode(MessageEnvelope.self, from: bodyData)
                    self.delegate?.transport(self, didReceiveEnvelope: envelope)
                } catch {
                    self.logger.error("Failed to decode MessageEnvelope: \(error.localizedDescription)")
                }

                self.receiveNextFrame()
            }
        }
    }
}

// Backward compatibility alias for any existing references
public typealias WebSocketTransport = FramedTCPTransport
public typealias WebSocketTransportDelegate = FramedTCPTransportDelegate
