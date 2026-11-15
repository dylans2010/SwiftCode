#if os(macOS)
import AppKit
import SwiftUI
import YcodeIDECore

public enum DeviceUtilitiesTarget: Sendable {
    case simulator(SimulatorDevice)
    case physicalDevice(name: String)
}

public struct DeviceHubUtilitiesView: View {
    private let target: DeviceUtilitiesTarget
    private let utilities: DeviceUtilities

    @State private var urlString = ""
    @State private var bundleID = ""
    @State private var payloadJSON = ""
    @State private var localFilePath = ""
    @State private var pushDestinationName = ""
    @State private var pullRelativePath = "Documents/"
    @State private var pullDestinationPath = ""
    @State private var selectedOrientation = SimulatorOrientation.portrait
    @State private var statusMessage: String?
    @State private var isBusy = false

    public init(target: DeviceUtilitiesTarget, utilities: DeviceUtilities = DeviceUtilities()) {
        self.target = target
        self.utilities = utilities
    }

    private var simulator: SimulatorDevice? {
        if case .simulator(let device) = target {
            return device
        }
        return nil
    }

    private var isSimulator: Bool {
        simulator != nil
    }

    private var simulatorBooted: Bool {
        simulator?.state == .booted
    }

    private var deviceTitle: String {
        switch target {
        case .simulator(let device):
            return device.name
        case .physicalDevice(let name):
            return name
        }
    }

    private var deviceSubtitle: String {
        switch target {
        case .simulator(let device):
            return "\(device.platform) \(device.osVersion) · \(device.state.rawValue)"
        case .physicalDevice:
            return "Physical device"
        }
    }

    private var actionsAvailable: Bool {
        isSimulator && simulatorBooted
    }

    public var body: some View {
        Form {
            Section(header: Text(deviceTitle)) {
                Text(deviceSubtitle)
                if isSimulator {
                    if simulatorBooted {
                        Text("Simulator-only utilities below run against this simulator through simctl.")
                    } else {
                        Text("Boot this simulator to use the utilities below.")
                    }
                } else {
                    Text("These utilities run against the iOS Simulator through simctl. Physical devices do not support them, so every action below is unavailable for this device.")
                }
            }

            Section(header: Text("Open URL")) {
                Text("Opens a deep link, URL scheme, or universal link in the simulator.")
                TextField("myapp:open", text: $urlString)
                    .disabled(!actionsAvailable)
                Button("Open URL") {
                    guard let device = simulator else { return }
                    let utilities = utilities
                    let url = urlString
                    run {
                        try await utilities.openURL(udid: device.udid, urlString: url)
                        return "Opened \(url)."
                    }
                }
                .disabled(!actionsAvailable || urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isBusy)
            }

            Section(header: Text("Push Notification")) {
                Text("Sends a simulated remote notification to the installed app. The payload must be a JSON object with an aps key and at most 4096 bytes.")
                TextField("Bundle Identifier", text: $bundleID)
                    .disabled(!actionsAvailable)
                TextEditor(text: $payloadJSON)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 120)
                    .disabled(!actionsAvailable)
                HStack {
                    Button("Insert Sample Payload") {
                        payloadJSON = DeviceUtilities.samplePushPayload(bundleID: bundleID)
                    }
                    .disabled(!actionsAvailable)
                    Button("Send Push Notification") {
                        guard let device = simulator else { return }
                        let utilities = utilities
                        let targetBundleID = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
                        let payload = payloadJSON
                        run {
                            let response = try await utilities.sendPushNotification(
                                udid: device.udid,
                                bundleID: targetBundleID.isEmpty ? nil : targetBundleID,
                                payloadJSON: payload
                            )
                            return response.isEmpty ? "Push notification sent." : response
                        }
                    }
                    .disabled(!actionsAvailable || payloadJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isBusy)
                }
            }

            Section(header: Text("Push File to Simulator")) {
                Text("Copies a file from this Mac into the app Documents folder inside the simulator container. File push and pull use the bundle identifier above.")
                HStack {
                    TextField("Local File Path", text: $localFilePath)
                    Button("Browse…") {
                        chooseLocalFile()
                    }
                }
                .disabled(!actionsAvailable)
                TextField("Destination File Name", text: $pushDestinationName)
                    .disabled(!actionsAvailable)
                Button("Push File") {
                    guard let device = simulator else { return }
                    let utilities = utilities
                    let sourcePath = localFilePath
                    let targetBundleID = bundleID
                    let destinationName = pushDestinationName.trimmingCharacters(in: .whitespacesAndNewlines)
                    run {
                        let destination = try await utilities.pushFile(
                            udid: device.udid,
                            bundleID: targetBundleID,
                            localFileURL: URL(fileURLWithPath: sourcePath),
                            destinationFileName: destinationName.isEmpty ? nil : destinationName
                        )
                        return "Pushed to \(destination.path)."
                    }
                }
                .disabled(!actionsAvailable || localFilePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || bundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isBusy)
            }

            Section(header: Text("Pull File from Simulator")) {
                Text("Copies a file out of the app container onto this Mac. The path is relative to the container, for example Documents/report.json.")
                TextField("Path Inside Container", text: $pullRelativePath)
                    .disabled(!actionsAvailable)
                HStack {
                    TextField("Destination Path", text: $pullDestinationPath)
                    Button("Choose…") {
                        choosePullDestination()
                    }
                }
                .disabled(!actionsAvailable)
                Button("Pull File") {
                    guard let device = simulator else { return }
                    let utilities = utilities
                    let relativePath = pullRelativePath
                    let targetBundleID = bundleID
                    let destinationPath = pullDestinationPath
                    run {
                        let destination = try await utilities.pullFile(
                            udid: device.udid,
                            bundleID: targetBundleID,
                            containerRelativePath: relativePath,
                            destinationURL: URL(fileURLWithPath: destinationPath)
                        )
                        return "Pulled to \(destination.path)."
                    }
                }
                .disabled(!actionsAvailable || pullRelativePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || pullDestinationPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || bundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isBusy)
            }

            Section(header: Text("Orientation")) {
                Picker("Orientation", selection: $selectedOrientation) {
                    ForEach(SimulatorOrientation.allCases, id: \.self) { orientation in
                        Text(orientation.displayName).tag(orientation)
                    }
                }
                .disabled(true)
                Text(DeviceUtilities.orientationUnavailableReason)
            }

            Section(header: Text("Status")) {
                if isBusy {
                    ProgressView()
                }
                if let statusMessage {
                    Text(statusMessage)
                        .textSelection(.enabled)
                } else {
                    Text("No utility has run yet.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func run(_ operation: @escaping @Sendable () async throws -> String) {
        statusMessage = nil
        isBusy = true
        Task {
            do {
                let message = try await operation()
                statusMessage = message
                isBusy = false
            } catch {
                statusMessage = error.localizedDescription
                isBusy = false
            }
        }
    }

    private func chooseLocalFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            localFilePath = url.path
            if pushDestinationName.isEmpty {
                pushDestinationName = url.lastPathComponent
            }
        }
    }

    private func choosePullDestination() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            pullDestinationPath = url.path
        }
    }
}
#endif
