import Foundation
import Combine

@MainActor
public final class ConnectAssistService: ObservableObject {
    public static let shared = ConnectAssistService()

    @Published public private(set) var lastAssistContext: AssistContextResponsePayload?
    @Published public private(set) var lastAssistAnswer: String?
    @Published public private(set) var isFetchingContext = false

    private var cancellables = Set<AnyCancellable>()

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

    public func requestRemoteContext(userQuery: String, projectPath: String? = nil) async throws -> AssistContextResponsePayload? {
        isFetchingContext = true
        defer { isFetchingContext = false }

        let payload = ConnectAssistQueryRequestPayload(
            prompt: userQuery,
            contextFiles: projectPath != nil ? [projectPath!] : nil
        )
        let envelope = try MessageEnvelope.encode(payload: payload, type: .assistQueryRequest)
        try await ConnectConnectionManager.shared.sendEnvelope(envelope)

        return lastAssistContext
    }

    private func handleEnvelope(_ envelope: MessageEnvelope) {
        switch envelope.type {
        case .assistResponse:
            if let response = try? envelope.decodePayload(ConnectAssistResponsePayload.self) {
                self.lastAssistAnswer = response.answer
                self.lastAssistContext = AssistContextResponsePayload(
                    projectSummary: response.answer,
                    activeBranch: "main",
                    contextSnippet: response.suggestedActions?.joined(separator: ", ")
                )
            } else if let directContext = try? envelope.decodePayload(AssistContextResponsePayload.self) {
                self.lastAssistContext = directContext
            }

        default:
            break
        }
    }
}
