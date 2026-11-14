import AppKit
import SwiftUI
import YcodeDeviceModel
import YcodeIDECore

@MainActor
public enum DeviceHubUnifiedWorkspace {

    public enum HubWorkspaceMode: Int, CaseIterable, Sendable {
        case canvas = 0
        case visualUI = 1
        case deviceConnect = 2

        public var title: String {
            switch self {
            case .canvas: return "Live Device"
            case .visualUI: return "Visual UI & Artboards"
            case .deviceConnect: return "Device Connect"
            }
        }

        public var iconName: String {
            switch self {
            case .canvas: return "iphone"
            case .visualUI: return "square.stack.3d.down.forward"
            case .deviceConnect: return "cable.connector"
            }
        }
    }

    public static var knownDeviceFrames: [String] { ArtboardWindowController.deviceFrames }

    public static func deviceFrame(for row: DeviceRow) -> String? {
        if knownDeviceFrames.contains(row.model) { return row.model }
        if knownDeviceFrames.contains(row.name) { return row.name }
        return nil
    }

    public static func makeConnectedDevice(from row: DeviceRow, isSimulator: Bool) -> ConnectedDevice {
        ConnectedDevice(
            name: row.name,
            model: row.model,
            productType: row.model,
            platform: row.platform,
            osVersion: row.osVersion,
            buildVersion: "",
            architecture: "arm64",
            udid: row.identifier,
            isConnected: isSimulator ? row.state == "Booted" : row.isAvailable,
            isAvailable: row.isAvailable,
            isWireless: false,
            isUSB: !isSimulator
        )
    }

    public static func syncDeviceWithDeviceConnect(_ row: DeviceRow?, isSimulator: Bool) {
        guard let row else { return }
        let device = makeConnectedDevice(from: row, isSimulator: isSimulator)
        DeviceConnectDeviceManager.shared.selectDevice(device)
    }

    public static func syncDeviceWithUIBuilder(_ row: DeviceRow?) {
        guard let row else { return }
        if let frame = deviceFrame(for: row) {
            VisualUISettings.shared.selectedDevice = frame
            PreviewManager.shared.changeDevice(to: frame)
        }
        if !row.isSwiftCodeRemote {
            SimulatorManager.shared.selectedDeviceID = row.identifier
        }
    }

    public static func openInDeviceConnect(_ row: DeviceRow, isSimulator: Bool) {
        syncDeviceWithDeviceConnect(row, isSimulator: isSimulator)
        DeviceConnectWindowManager.shared.showWindow()
    }

    public static func openInUIBuilder(_ row: DeviceRow, hub: DevicesController) {
        syncDeviceWithUIBuilder(row)
        if !row.isSwiftCodeRemote {
            if row.state != "Booted" {
                Task { await SimulatorManager.shared.bootSelectedDevice() }
            }
        } else if row.state != "Booted" {
            _ = hub.start(row)
        }
        VisualUIBuilderWindowManager.shared.showWindow()
    }

    

    public static func isTablet(for row: DeviceRow) -> Bool {
        row.model.contains("iPad") || row.name.contains("iPad") || row.platform.contains("iPad")
    }

    public static func isIPad(for row: DeviceRow) -> Bool {
        isTablet(for: row)
    }

    public struct TabletPreset: Identifiable, Sendable {
        public var id: String { name }
        public let name: String
        public let model: String
        public let screenSize: String
        public let supportsStageManager: Bool
        public let supportsPencilHover: Bool

        public init(name: String, model: String, screenSize: String, supportsStageManager: Bool, supportsPencilHover: Bool) {
            self.name = name
            self.model = model
            self.screenSize = screenSize
            self.supportsStageManager = supportsStageManager
            self.supportsPencilHover = supportsPencilHover
        }
    }

    public static let iPadPresets: [TabletPreset] = [
        TabletPreset(name: "iPad Pro 13-inch (M4)", model: "iPad16,5", screenSize: "13\"", supportsStageManager: true, supportsPencilHover: true),
        TabletPreset(name: "iPad Pro 11-inch (M4)", model: "iPad16,3", screenSize: "11\"", supportsStageManager: true, supportsPencilHover: true),
        TabletPreset(name: "iPad Air 13-inch (M2)", model: "iPad14,10", screenSize: "13\"", supportsStageManager: true, supportsPencilHover: true),
        TabletPreset(name: "iPad Air 11-inch (M2)", model: "iPad14,8", screenSize: "11\"", supportsStageManager: true, supportsPencilHover: true),
        TabletPreset(name: "iPad mini (A17 Pro)", model: "iPad16,1", screenSize: "8.3\"", supportsStageManager: false, supportsPencilHover: true),
        TabletPreset(name: "iPad (10th generation)", model: "iPad13,18", screenSize: "10.9\"", supportsStageManager: false, supportsPencilHover: false),
    ]

    

    public static func cloneSimulator(udid: String, newName: String) async throws -> String {
        try await DeviceHubSimulatorInstaller.cloneSimulator(sourceUDID: udid, newName: newName)
    }

    public static func eraseSimulator(udid: String) async throws {
        try await DeviceHubSimulatorInstaller.eraseSimulator(udid: udid)
    }

    public static func eraseAllSimulators() async throws {
        try await DeviceHubSimulatorInstaller.eraseAllSimulators()
    }

    public static func bootSimulator(udid: String) async throws {
        try await DeviceHubSimulatorInstaller.bootSimulator(udid: udid)
    }

    public static func shutdownSimulator(udid: String) async throws {
        try await DeviceHubSimulatorInstaller.shutdownSimulator(udid: udid)
    }

    public static func shutdownAllSimulators() async throws {
        try await DeviceHubSimulatorInstaller.shutdownAllSimulators()
    }

    public static func setAppearance(udid: String, isDark: Bool) async throws {
        try await DeviceHubSimulatorInstaller.setAppearance(udid: udid, appearance: isDark ? "dark" : "light")
    }

    public static func setContentSize(udid: String, size: String) async throws {
        try await DeviceHubSimulatorInstaller.setContentSize(udid: udid, size: size)
    }

    public static func setAccessibility(udid: String, increaseContrast: Bool? = nil, reduceMotion: Bool? = nil) async throws {
        if let increaseContrast {
            try await DeviceHubSimulatorInstaller.setIncreaseContrast(udid: udid, enabled: increaseContrast)
        }
        if let reduceMotion {
            try await DeviceHubSimulatorInstaller.setReduceMotion(udid: udid, enabled: reduceMotion)
        }
    }

    public static func setLocation(udid: String, latitude: Double, longitude: Double) async throws {
        try await DeviceHubSimulatorInstaller.setLocation(udid: udid, latitude: latitude, longitude: longitude)
    }

    public static func runLocationScenario(udid: String, scenario: String) async throws {
        try await DeviceHubSimulatorInstaller.runLocationScenario(udid: udid, scenario: scenario)
    }

    public static func clearLocation(udid: String) async throws {
        try await DeviceHubSimulatorInstaller.clearLocation(udid: udid)
    }

    public static func setBattery(udid: String, level: Int, state: String = "charged") async throws {
        try await DeviceHubSimulatorInstaller.overrideStatusBar(udid: udid, batteryLevel: level, batteryState: state)
    }

    public static func setNetworkCondition(udid: String, dataNetwork: String, wifiBars: Int = 3, cellularBars: Int = 4, operatorName: String = "SwiftCode Net") async throws {
        try await DeviceHubSimulatorInstaller.overrideStatusBar(
            udid: udid,
            dataNetwork: dataNetwork,
            wifiMode: "active",
            wifiBars: wifiBars,
            cellularMode: "active",
            cellularBars: cellularBars,
            operatorName: operatorName
        )
    }

    public static func resetStatusBar(udid: String) async throws {
        try await DeviceHubSimulatorInstaller.clearStatusBar(udid: udid)
    }

    public static func setStageManager(udid: String, enabled: Bool) async throws {
        try await DeviceHubSimulatorInstaller.setStageManager(udid: udid, enabled: enabled)
    }

    public static func simulateApplePencil(udid: String, action: String) async throws {
        try await DeviceHubSimulatorInstaller.simulateApplePencilAction(udid: udid, action: action)
    }
}
