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
}
