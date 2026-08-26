import Foundation
import Combine

@MainActor
public final class ConnectProjectService: ObservableObject {
    public static let shared = ConnectProjectService()

    @Published public private(set) var remoteProjectState: RemoteProjectStatePayload?
    @Published public private(set) var isLoading = false

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

    public func fetchProjectState() async throws {
        isLoading = true
        defer { isLoading = false }

        let envelope = try ConnectMessageEnvelope.makeEnvelope(
            type: .getProjectState,
            payload: ["request": "state"]
        )
        try await ConnectConnectionManager.shared.sendEnvelope(envelope)
    }

    private func handleEnvelope(_ envelope: ConnectMessageEnvelope) {
        guard envelope.type == .projectStateUpdate else { return }
        do {
            let state = try envelope.decodePayload(RemoteProjectStatePayload.self)
            self.remoteProjectState = state
        } catch {
            print("[ConnectProjectService] Failed to decode project state: \(error)")
        }
    }
}
