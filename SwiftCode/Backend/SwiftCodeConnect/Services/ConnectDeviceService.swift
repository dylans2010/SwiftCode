import Foundation
import Combine

@MainActor
public final class ConnectDeviceService: ObservableObject {
    public static let shared = ConnectDeviceService()

    @Published public private(set) var remoteDeviceState: RemoteDeviceStatePayload?
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

    public func fetchDeviceInfo() async throws {
        isLoading = true
        defer { isLoading = false }

        let envelope = try ConnectMessageEnvelope.makeEnvelope(type: .getDeviceInfo, payload: ["request": "info"])
        try await ConnectConnectionManager.shared.sendEnvelope(envelope)
    }

    private func handleEnvelope(_ envelope: ConnectMessageEnvelope) {
        guard envelope.type == .deviceInfoResponse else { return }
        do {
            let info = try envelope.decodePayload(RemoteDeviceStatePayload.self)
            self.remoteDeviceState = info
        } catch {
            print("[ConnectDeviceService] Failed to decode device info: \(error)")
        }
    }
}
