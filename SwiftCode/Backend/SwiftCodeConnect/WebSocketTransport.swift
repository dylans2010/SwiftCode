import Foundation

public enum TransportState: Equatable {
    case disconnected
    case connecting
    case authenticating
    case connected
    case failed(String)
}

public protocol WebSocketTransportDelegate: AnyObject {
    func transport(_ transport: WebSocketTransport, didReceiveEnvelope envelope: ConnectMessageEnvelope)
    func transport(_ transport: WebSocketTransport, didChangeState state: TransportState)
    func transport(_ transport: WebSocketTransport, didFailWithError error: Error)
}

public final class WebSocketTransport: NSObject {
    public private(set) var state: TransportState = .disconnected {
        didSet {
            delegate?.transport(self, didChangeState: state)
        }
    }

    public weak var delegate: WebSocketTransportDelegate?
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var pingTimer: Timer?
    private let url: URL
    private let authToken: String?

    public init(url: URL, authToken: String? = nil) {
        self.url = url
        self.authToken = authToken
        super.init()
    }

    public func connect() {
        guard state == .disconnected || case .failed = state else { return }
        state = .connecting

        let configuration = URLSessionConfiguration.default
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue())

        var request = URLRequest(url: url)
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        webSocketTask = session?.webSocketTask(with: request)
        webSocketTask?.resume()

        startListening()
        startPingTimer()
    }

    public func disconnect() {
        stopPingTimer()
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        session?.invalidateAndCancel()
        session = nil
        state = .disconnected
    }

    public func send(envelope: ConnectMessageEnvelope) async throws {
        guard webSocketTask != nil else {
            throw ConnectProtocolError.deviceUnavailable
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(envelope)

        let message = URLSessionWebSocketTask.Message.data(data)
        try await webSocketTask?.send(message)
    }

    private func startListening() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                self.handleReceivedMessage(message)
                self.startListening()
            case .failure(let error):
                self.state = .failed(error.localizedDescription)
                self.delegate?.transport(self, didFailWithError: error)
            }
        }
    }

    private func handleReceivedMessage(_ message: URLSessionWebSocketTask.Message) {
        let data: Data?
        switch message {
        case .data(let d):
            data = d
        case .string(let s):
            data = s.data(using: .utf8)
        @unknown default:
            data = nil
        }

        guard let payloadData = data else { return }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let envelope = try decoder.decode(ConnectMessageEnvelope.self, from: payloadData)
            if envelope.type == .authResponse {
                self.state = .connected
            }
            delegate?.transport(self, didReceiveEnvelope: envelope)
        } catch {
            print("[WebSocketTransport] Failed to decode envelope: \(error)")
        }
    }

    private func startPingTimer() {
        stopPingTimer()
        DispatchQueue.main.async { [weak self] in
            self?.pingTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
                self?.sendPing()
            }
        }
    }

    private func stopPingTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
    }

    private func sendPing() {
        webSocketTask?.sendPing { [weak self] error in
            if let error = error {
                print("[WebSocketTransport] Ping failed: \(error)")
                self?.state = .failed(error.localizedDescription)
            }
        }
    }
}

extension WebSocketTransport: URLSessionWebSocketDelegate {
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("[WebSocketTransport] Socket opened")
        state = authToken != nil ? .authenticating : .connected
    }

    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        state = .disconnected
    }
}
