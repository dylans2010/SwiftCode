#if os(macOS)
import SwiftUI
import YcodeDeviceModel
import YcodeIDECore

public struct DeviceHubOverviewView: View {
    private let snapshot: DeviceHubOverviewSnapshot
    private let onRefresh: () -> Void

    public init(snapshot: DeviceHubOverviewSnapshot, onRefresh: @escaping () -> Void) {
        self.snapshot = snapshot
        self.onRefresh = onRefresh
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Device Hub Overview")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Live state from the simulator, platform, and environment managers.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Refresh") { onRefresh() }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    statCard(title: "Physical Devices", value: "\(snapshot.connectedPhysicalDevices)", detail: "connected and available")
                    statCard(title: "Simulators", value: "\(snapshot.availableSimulators)", detail: "\(snapshot.bootedSimulators) booted")
                    statCard(title: "Installed Platforms", value: "\(snapshot.installedPlatforms.count)", detail: snapshot.installedPlatforms.isEmpty ? "none installed" : snapshot.installedPlatforms.joined(separator: ", "))
                    statCard(title: "Simulator Runtimes", value: "\(snapshot.installedRuntimes)", detail: "\(snapshot.availableRuntimes) available")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Toolchain", systemImage: "hammer")
                            .font(.headline)
                        Text(snapshot.toolchainSummary)
                        HStack {
                            Text("Xcode")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(snapshot.xcodeDisplay)
                        }
                        HStack {
                            Text("Developer directory")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(snapshot.developerDirectoryDisplay)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        if snapshot.isCommandLineToolsOnly {
                            Text("Only the Command Line Tools are installed. Simulator runtimes and SDKs need full Xcode.")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        if !snapshot.missingPlatforms.isEmpty {
                            Text("Missing platforms: \(snapshot.missingPlatforms.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                }

                if let error = snapshot.lastError {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Last Discovery Problem", systemImage: "exclamationmark.triangle")
                                .font(.headline)
                                .foregroundStyle(.orange)
                            Text(error)
                                .font(.caption)
                                .textSelection(.enabled)
                        }
                        .padding()
                    }
                }

                if !snapshot.globalIssues.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Platform Issues", systemImage: "exclamationmark.circle")
                                .font(.headline)
                            ForEach(snapshot.globalIssues, id: \.self) { issue in
                                Text(issue)
                                    .font(.caption)
                            }
                        }
                        .padding()
                    }
                }

                if !snapshot.hasScanned {
                    Text("The toolchain has not been scanned yet. Refresh to probe Xcode, the developer directory, SDKs, and runtimes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
    }

    private func statCard(title: String, value: String, detail: String) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
        }
    }
}

public struct DeviceHubPlatformsView: View {
    private let snapshot: PlatformCatalogSnapshot

    public init(snapshot: PlatformCatalogSnapshot) {
        self.snapshot = snapshot
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Platforms")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("SDKs and simulator runtimes per platform, from the SDK registry, the on-disk runtime scan, and simctl.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !snapshot.hasScanned {
                    Text("Platforms have not been scanned yet. Open Overview and refresh to scan.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(snapshot.platforms) { platform in
                    GroupBox {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(platform.displayName)
                                    .font(.headline)
                                Spacer()
                                Text(platform.status.rawValue.capitalized)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(platform.status == .installed ? .green : .orange)
                            }
                            if !platform.sdks.isEmpty {
                                Text("SDKs: \(platform.sdks.map { "\($0.displayName) \($0.version)" }.joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if !platform.runtimes.isEmpty {
                                Text("Runtimes: \(platform.runtimes.map { "\($0.name) \($0.version)" }.joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if platform.sdks.isEmpty && platform.runtimes.isEmpty {
                                Text("No SDK or runtime found for this platform.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            ForEach(platform.issues) { issue in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(issue.message)
                                        .font(.caption)
                                    Text(issue.remediation)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            if !platform.installationLocations.isEmpty {
                                Text("Locations: \(platform.installationLocations.joined(separator: ", "))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(4)
                    }
                }
            }
            .padding()
        }
    }
}

public struct DeviceHubDiagnosticsView: View {
    private let snapshot: PlatformCatalogSnapshot

    public init(snapshot: PlatformCatalogSnapshot) {
        self.snapshot = snapshot
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Diagnostics")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Environment and platform health. Device-specific logs and crash reports stay in the inspector Reports tab.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Environment", systemImage: "checkmark.seal")
                            .font(.headline)
                        HStack {
                            Text("Xcode installed")
                            Spacer()
                            Text(snapshot.isXcodeInstalled ? "Yes" : "No")
                        }
                        HStack {
                            Text("Command Line Tools only")
                            Spacer()
                            Text(snapshot.isCommandLineToolsOnly ? "Yes" : "No")
                        }
                        HStack {
                            Text("Xcode version")
                            Spacer()
                            Text(snapshot.xcodeVersion ?? "Unknown")
                        }
                        HStack {
                            Text("Developer directory")
                            Spacer()
                            Text(snapshot.developerDirectory ?? "Unknown")
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        if let error = snapshot.discoveryError {
                            Text("Discovery error: \(error)")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(4)
                }

                if snapshot.globalIssues.isEmpty {
                    Text("No global platform issues were reported.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(snapshot.globalIssues) { issue in
                        GroupBox {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(issue.message)
                                    .font(.subheadline)
                                Text(issue.remediation)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(4)
                        }
                    }
                }

                ForEach(snapshot.platforms.filter { !$0.issues.isEmpty }) { platform in
                    GroupBox {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(platform.displayName)
                                .font(.headline)
                            ForEach(platform.issues) { issue in
                                Text(issue.message)
                                    .font(.caption)
                                Text(issue.remediation)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(4)
                    }
                }
            }
            .padding()
        }
    }
}
#endif
