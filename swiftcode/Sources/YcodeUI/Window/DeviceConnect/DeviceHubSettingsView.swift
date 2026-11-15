#if os(macOS)
import AppKit
import SwiftUI
import YcodeDeviceModel

public struct DeviceHubPreferencesSection: View {
    @State private var prefs = DeviceConnectPreferencesManager.shared

    public init() {}

    public var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Automation Controls", systemImage: "bolt.ring.closed")
                        .font(.headline)
                        .foregroundColor(.orange)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Automatically Discover Connected Devices", isOn: $prefs.autoDiscover)
                    Toggle("Auto-Validate Environment on Open", isOn: $prefs.autoValidate)
                    Toggle("Automatically Save Editor state before Deployment", isOn: $prefs.autoSaveBeforeDeploy)
                    Toggle("Automatically Launch Application post Successful Install", isOn: $prefs.autoLaunch)
                    Toggle("Automatically stream Runtime Syslog Console on run", isOn: $prefs.autoStreamLogs)
                }
            }
            .padding()
        }

        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Log & History Retention", systemImage: "clock.arrow.circlepath")
                        .font(.headline)
                        .foregroundColor(.blue)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Keep Deployment & Session history", isOn: $prefs.keepHistory)
                    HStack {
                        Text("Maximum Sessions in Memory:")
                        Spacer()
                        Picker("", selection: $prefs.maxSessionCount) {
                            Text("25").tag(25)
                            Text("50").tag(50)
                            Text("100").tag(100)
                            Text("Unlimited").tag(9999)
                        }
                        .frame(width: 120)
                    }
                }
            }
            .padding()
        }
    }
}

struct HubAppKitSettingsView: NSViewRepresentable {
    let makeView: () -> NSView

    func makeNSView(context: Context) -> NSView {
        makeView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

public struct DeviceHubSettingsView: View {
    private let hub: DevicesController

    public init(hub: DevicesController) {
        self.hub = hub
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DeviceHubPreferencesSection()

                if let row = hub.selected {
                    if row.isSwiftCodeRemote {
                        Text("Remote Simulator")
                            .font(.headline)
                        HubAppKitSettingsView { hub.settingsControls() }
                        if hub.cameraControlsShown {
                            HubAppKitSettingsView { hub.cameraControls() }
                        }
                        if hub.headsetControlsShown {
                            HubAppKitSettingsView { hub.headsetControls() }
                        }
                    } else if hub.isLocalSimulator(row) {
                        Text("Simulator")
                            .font(.headline)
                        HubAppKitSettingsView { hub.localSettingsControls() }
                        Text("Simulator settings are applied with simctl and the simulator defaults database. Appearance and battery start from the last values SwiftCode read or applied for this simulator.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(DevicesController.noSettingsMessage)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("No Selection")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
        }
    }
}
#endif
