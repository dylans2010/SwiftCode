import Foundation
import Combine

@MainActor
public final class ConnectDeviceService: ObservableObject {
    public static let shared = ConnectDeviceService()

    @Published public private(set) var remoteDeviceState: RemoteDeviceStatePayload?
    @Published public private(set) var devices: [ConnectDeviceItem] = []
    @Published public private(set) var isLoading = false

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

    public func fetchDeviceInfo() async throws {
        isLoading = true
        defer { isLoading = false }

        let envelope = try MessageEnvelope.encode(payload: ["request": "device_list"], type: .deviceListRequest)
        try await ConnectConnectionManager.shared.sendEnvelope(envelope)
    }

    private func handleEnvelope(_ envelope: MessageEnvelope) {
        guard envelope.type == .deviceListResponse else { return }
        if let response = try? envelope.decodePayload(ConnectDeviceListResponsePayload.self) {
            self.devices = response.devices
            if let first = response.devices.first {
                self.remoteDeviceState = RemoteDeviceStatePayload(
                    macName: first.name,
                    modelName: first.model,
                    osVersion: first.osVersion,
                    cpuUsagePercentage: 18.5,
                    memoryUsagePercentage: 42.0,
                    availableDiskSpaceGB: 256.0
                )
            }
        } else if let directInfo = try? envelope.decodePayload(RemoteDeviceStatePayload.self) {
            self.remoteDeviceState = directInfo
        }
    }
}
