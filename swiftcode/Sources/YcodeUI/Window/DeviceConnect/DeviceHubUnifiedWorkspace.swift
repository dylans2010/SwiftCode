import AppKit
import YcodeDeviceModel
import YcodeIDECore











@MainActor
public enum DeviceHubUnifiedWorkspace {

    
    
    
    
    public static var knownDeviceFrames: [String] { ArtboardWindowController.deviceFrames }

    
    
    
    
    public static func deviceFrame(for row: DeviceRow) -> String? {
        if knownDeviceFrames.contains(row.model) { return row.model }
        if knownDeviceFrames.contains(row.name) { return row.name }
        return nil
    }

    
    
    
    
    
    
    public static func openInDeviceConnect(_ row: DeviceRow, isSimulator: Bool) {
        let device = ConnectedDevice(
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
            isUSB: !isSimulator)
        DeviceConnectDeviceManager.shared.selectDevice(device)
        DeviceConnectWindowManager.shared.showWindow()
    }

    
    
    
    
    
    
    
    public static func openInUIBuilder(_ row: DeviceRow, hub: DevicesController) {
        if let frame = deviceFrame(for: row) {
            VisualUISettings.shared.selectedDevice = frame
            PreviewManager.shared.changeDevice(to: frame)
        }
        if !row.isSwiftCodeRemote {
            SimulatorManager.shared.selectedDeviceID = row.identifier
            if row.state != "Booted" {
                Task { await SimulatorManager.shared.bootSelectedDevice() }
            }
        } else if row.state != "Booted" {
            _ = hub.start(row)
        }
        VisualUIBuilderWindowManager.shared.showWindow()
    }
}
