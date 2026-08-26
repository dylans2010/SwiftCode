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
            .compactMap { $0.object as? ConnectMessageEnvelope }
            .sink { [weak self] envelope in
                Task { @MainActor [weak self] in
                    self?.handleEnvelope(envelope)
                }
            }
            .store(in: &cancellables)
    }

    public func subscribe(minimumLogLevel: LogLevel = .info, categoryFilter: String? = nil) async throws {
        let payload = LogStreamSubscriptionPayload(isEnabled: true, minimumLogLevel: minimumLogLevel, categoryFilter: categoryFilter)
        let envelope = try ConnectMessageEnvelope.makeEnvelope(type: .logStreamSubscribe, payload: payload)
        try await ConnectConnectionManager.shared.sendEnvelope(envelope)
        isSubscribed = true
    }

    public func unsubscribe() async throws {
        let payload = LogStreamSubscriptionPayload(isEnabled: false)
        let envelope = try ConnectMessageEnvelope.makeEnvelope(type: .logStreamUnsubscribe, payload: payload)
        try await ConnectConnectionManager.shared.sendEnvelope(envelope)
        isSubscribed = false
    }

    public func clearLogs() {
        logs.removeAll()
    }

    private func handleEnvelope(_ envelope: ConnectMessageEnvelope) {
        guard envelope.type == .logEntry else { return }
        do {
            let entry = try envelope.decodePayload(RemoteLogEntryPayload.self)
            logs.append(entry)
            if logs.count > maxLogsLimit {
                logs.removeFirst(logs.count - maxLogsLimit)
            }
        } catch {
            print("[ConnectLogService] Failed to decode log entry: \(error)")
        }
    }
}
