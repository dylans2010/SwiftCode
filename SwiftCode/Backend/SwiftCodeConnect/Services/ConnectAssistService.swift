import Foundation
import Combine

@MainActor
public final class ConnectAssistService: ObservableObject {
    public static let shared = ConnectAssistService()

    @Published public private(set) var lastAssistContext: AssistContextResponsePayload?
    @Published public private(set) var isFetchingContext = false

    private var cancellables = Set<AnyCancellable>()

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

    public func requestRemoteContext(userQuery: String, projectPath: String? = nil) async throws -> AssistContextResponsePayload? {
        isFetchingContext = true
        defer { isFetchingContext = false }

        let payload = AssistContextRequestPayload(
            userQuery: userQuery,
            projectPath: projectPath,
            includeDiagnostics: true,
            includeRecentLogs: true
        )
        let envelope = try ConnectMessageEnvelope.makeEnvelope(type: .assistContextRequest, payload: payload)
        try await ConnectConnectionManager.shared.sendEnvelope(envelope)

        // Return current cached or awaited response payload
        return lastAssistContext
    }

    private func handleEnvelope(_ envelope: ConnectMessageEnvelope) {
        guard envelope.type == .assistContextResponse else { return }
        do {
            let context = try envelope.decodePayload(AssistContextResponsePayload.self)
            self.lastAssistContext = context
        } catch {
            print("[ConnectAssistService] Failed to decode Assist context: \(error)")
        }
    }
}
