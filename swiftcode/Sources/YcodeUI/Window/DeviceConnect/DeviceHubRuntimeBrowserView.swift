#if os(macOS)
import SwiftUI
import YcodeDeviceModel
import YcodeIDECore

@MainActor
public final class DeviceHubRuntimeBrowserViewModel: ObservableObject {
    private let browser = DeviceHubRuntimeBrowser()

    @Published public var entries: [DeviceHubRuntimeEntry] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public var statusMessage: String?
    @Published public var selectedPlatform: DeviceHubPlatform = .iOS
    @Published public var isInstalling = false

    public init() {}

    public func load() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let disk = await SimulatorRuntimeManager.shared.discoverRuntimes()
                var paths: [String: String] = [:]
                for runtime in disk {
                    if let path = runtime.path { paths[runtime.identifier] = path }
                }
                let listed = try await browser.listRuntimes()
                let merged = DeviceHubRuntimeEntry.merged(simctlEntries: listed, diskPaths: paths)
                    .map { $0.withDiskSize() }
                    .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                await MainActor.run {
                    self.entries = merged
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.entries = []
                    self.isLoading = false
                }
            }
        }
    }

    public func verify(_ entry: DeviceHubRuntimeEntry) {
        Task {
            do {
                let found = try await browser.verifyInstalled(identifier: entry.identifier)
                await MainActor.run {
                    self.statusMessage = found
                        ? "Verified: \(entry.name) is listed by simctl."
                        : "\(entry.name) is no longer listed by simctl."
                    self.errorMessage = nil
                }
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }

    public func remove(_ entry: DeviceHubRuntimeEntry) {
        Task {
            do {
                try await browser.removeRuntime(identifier: entry.identifier)
                await MainActor.run {
                    self.statusMessage = "Removed \(entry.name)."
                    self.errorMessage = nil
                }
                load()
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }

    public func installSelectedPlatform() {
        guard !isInstalling else { return }
        isInstalling = true
        errorMessage = nil
        let platform = selectedPlatform
        DeviceHubSimulatorInstaller.shared.installPlatform(platform) { [weak self] success in
            guard let self else { return }
            self.isInstalling = false
            if success {
                self.statusMessage = "\(platform.title) installed and verified."
                self.load()
            } else {
                self.errorMessage = DeviceHubSimulatorInstaller.shared.errorMessage ?? "\(platform.title) install failed."
            }
        }
    }
}

public struct DeviceHubRuntimeBrowserView: View {
    @StateObject private var model = DeviceHubRuntimeBrowserViewModel()
    private let compact: Bool

    public init(compact: Bool = false) {
        self.compact = compact
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !compact {
                HStack {
                    Text("Simulator Runtimes")
                        .font(.headline)
                    Spacer()
                    Button("Refresh") { model.load() }
                        .disabled(model.isLoading || model.isInstalling)
                }
                Picker("Platform", selection: $model.selectedPlatform) {
                    ForEach(DeviceHubPlatform.allCases) { platform in
                        Text(platform.title).tag(platform)
                    }
                }
                .pickerStyle(.segmented)
            }

            if model.isLoading {
                ProgressView("Loading runtimes…")
            } else if model.entries.isEmpty {
                Text(model.errorMessage ?? "No simulator runtimes are installed. Install a platform runtime to create simulators for it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.entries) { entry in
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("\(entry.platform.rawValue) · \(entry.isAvailable ? "Available" : "Unavailable") · Size: \(entry.sizeDisplay)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !entry.supportedDeviceTypes.isEmpty {
                                Text("Supports \(entry.supportedDeviceTypes.count) device types")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button("Verify") {
                            model.verify(entry)
                        }
                        .controlSize(.small)
                        .disabled(model.isLoading)
                        Button("Remove") {
                            model.remove(entry)
                        }
                        .controlSize(.small)
                        .disabled(model.isLoading)
                    }
                    Divider()
                }
            }

            if !compact {
                HStack {
                    Button("Install \(model.selectedPlatform.title)") {
                        model.installSelectedPlatform()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isInstalling || model.isLoading)
                    if model.isInstalling {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                Text("Install downloads the platform with xcodebuild, then verifies the runtime appears in a fresh simctl list before reporting success.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let statusMessage = model.statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .onAppear { model.load() }
    }
}
#endif
