import Foundation
import os
import YcodeDeviceModel

public struct DeviceDiscoverySnapshot: Sendable {
    public let simulators: [DeviceRow]
    public let devices: [DeviceRow]
    public let discoveredAt: Date

    public init(simulators: [DeviceRow], devices: [DeviceRow], discoveredAt: Date = Date()) {
        self.simulators = simulators
        self.devices = devices
        self.discoveredAt = discoveredAt
    }
}

public enum DeviceDiscoveryError: Error, LocalizedError, Sendable {
    case simctlFailed(String)
    case devicectlFailed(String)
    case invalidJSON(String)
    case toolMissing(String)

    public var errorDescription: String? {
        switch self {
        case .simctlFailed(let message):
            return "Simulator discovery failed: \(message)"
        case .devicectlFailed(let message):
            return "Physical device discovery failed: \(message)"
        case .invalidJSON(let message):
            return "Device discovery returned unparsable output: \(message)"
        case .toolMissing(let message):
            return message
        }
    }
}

public actor DeviceDiscoveryService {
    public static let shared = DeviceDiscoveryService()

    private init() {}

    public func discover() async throws -> DeviceDiscoverySnapshot {
        async let simulators = discoverSimulators()
        async let devices = discoverPhysicalDevices()
        let snapshot = try await DeviceDiscoverySnapshot(simulators: simulators, devices: devices, discoveredAt: Date())
        Logger.discovery.info("[DISCOVERY-SERVICE] Discovered \(snapshot.simulators.count) simulators and \(snapshot.devices.count) physical devices.")
        return snapshot
    }

    private func discoverSimulators() async throws -> [DeviceRow] {
        let result: SimctlDiscoveryResult
        do {
            result = try await SimctlDiscoveryClient.shared.fetchDiscoveryData()
        } catch {
            throw DeviceDiscoveryError.simctlFailed(error.localizedDescription)
        }
        return DevicesList.simulatorRows(from: result)
    }

    private func discoverPhysicalDevices() async throws -> [DeviceRow] {
        let xcrunURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        guard FileManager.default.isExecutableFile(atPath: xcrunURL.path) else {
            throw DeviceDiscoveryError.toolMissing("xcrun is not available at /usr/bin/xcrun.")
        }
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("swiftcode-devices-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }
        let result: DeviceConnectProcessResult
        do {
            result = try await DeviceConnectProcessRunner.shared.run(
                executableURL: xcrunURL,
                arguments: ["devicectl", "list", "devices", "--json-output", file.path, "-q"],
                timeout: 30
            )
        } catch {
            throw DeviceDiscoveryError.devicectlFailed(error.localizedDescription)
        }
        guard result.exitCode == 0 else {
            let detail = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw DeviceDiscoveryError.devicectlFailed(detail.isEmpty ? "devicectl exited with code \(result.exitCode)." : detail)
        }
        guard let data = try? Data(contentsOf: file) else {
            throw DeviceDiscoveryError.devicectlFailed("devicectl produced no JSON output.")
        }
        do {
            return try DevicesList.parsePhysicalDevices(data: data)
        } catch {
            throw DeviceDiscoveryError.invalidJSON(error.localizedDescription)
        }
    }
}
