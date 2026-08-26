import Foundation
import Combine

@MainActor
public final class ConnectLogService: ObservableObject {
    public static let shared = ConnectLogService()

    @Published public private(set) var isSubscribed = false
    @Published public private(set) var logs: [RemoteLogEntryPayload] = []
    @Published public var filterQuery = ""
    @Published public var selectedLogLevelFilter: LogLevel?

    private var cancellables = Set<AnyCancellable>()
    private let maxLogsLimit = 1000

    public var filteredLogs: [RemoteLogEntryPayload] {
        logs.filter { entry in
            if let minLevel = selectedLogLevelFilter, entry.level < minLevel {
                return false
            }
            if !filterQuery.isEmpty {
                let text = "\(entry.source) \(entry.category) \(entry.message)"
                return text.localizedCaseInsensitiveContains(filterQuery)
            }
            return true
        }
    }

    private init() {
        NotificationCenter.default.publisher(for: .connectEnvelopeReceived)
            .compactMap { $0.object as? MessageEnvelope }
            .sink { [weak self] envelope in
                Task { @MainActor [weak self] in
                    self?.handleEnvelope(envelope)
                }
            }
            .store(in: &cancellables)
    }

    public func subscribe(minimumLogLevel: LogLevel = .info, categoryFilter: String? = nil) async throws {
        let envelope = try MessageEnvelope.encode(payload: ["subscribe": true], type: .logsSubscribeRequest)
        try await ConnectConnectionManager.shared.sendEnvelope(envelope)
        isSubscribed = true
    }

    public func unsubscribe() async throws {
        let envelope = try MessageEnvelope.encode(payload: ["subscribe": false], type: .logsUnsubscribeRequest)
        try await ConnectConnectionManager.shared.sendEnvelope(envelope)
        isSubscribed = false
    }

    public func clearLogs() {
        logs.removeAll()
    }

    private func handleEnvelope(_ envelope: MessageEnvelope) {
        guard envelope.type == .logEvent else { return }
        if let event = try? envelope.decodePayload(ConnectLogEventPayload.self) {
            let level: LogLevel
            switch event.level.lowercased() {
            case "debug": level = .debug
            case "warning", "warn": level = .warning
            case "error": level = .error
            case "fault": level = .fault
            default: level = .info
            }
            let entry = RemoteLogEntryPayload(
                timestamp: event.timestamp,
                level: level,
                source: "Mac",
                category: event.category,
                message: event.message
            )
            logs.append(entry)
            if logs.count > maxLogsLimit {
                logs.removeFirst(logs.count - maxLogsLimit)
            }
        } else if let remoteEntry = try? envelope.decodePayload(RemoteLogEntryPayload.self) {
            logs.append(remoteEntry)
            if logs.count > maxLogsLimit {
                logs.removeFirst(logs.count - maxLogsLimit)
            }
        }
    }
}
