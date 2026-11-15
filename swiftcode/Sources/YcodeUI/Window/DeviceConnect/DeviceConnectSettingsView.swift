import SwiftUI
import YcodeDeviceModel

public struct DeviceConnectSettingsView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 24) {
            DeviceHubPreferencesSection()
        }
    }
}

