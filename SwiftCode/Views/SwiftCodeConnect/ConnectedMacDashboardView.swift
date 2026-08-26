import SwiftUI

struct ConnectedMacDashboardView: View {
    @StateObject private var connectionManager = ConnectConnectionManager.shared
    @StateObject private var projectService = ConnectProjectService.shared
    @StateObject private var buildService = ConnectBuildService.shared
    @StateObject private var deviceService = ConnectDeviceService.shared

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.07, blue: 0.12),
                    Color(red: 0.10, green: 0.10, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    macHeaderCard

                    projectStatusCard

                    gitStateCard

                    buildConsoleShortcutCard

                    deviceMetricsCard
                }
                .padding()
            }
        }
        .navigationTitle("Connected Mac")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            try? await projectService.fetchProjectState()
            try? await deviceService.fetchDeviceInfo()
        }
        .refreshable {
            try? await projectService.fetchProjectState()
            try? await deviceService.fetchDeviceInfo()
        }
    }

    private var macHeaderCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "desktopcomputer")
                .font(.largeTitle)
                .foregroundStyle(.cyan)

            VStack(alignment: .leading, spacing: 4) {
                Text(connectionManager.activeConnectedMac?.name ?? "Mac Studio")
                    .font(.title3).bold()
                    .foregroundStyle(.white)

                HStack(spacing: 6) {
                    Circle().fill(.green).frame(width: 8, height: 8)
                    Text("SwiftCode Connect Protocol v\(ConnectProtocolVersion.current)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var projectStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Mac Project")
                .font(.headline)
                .foregroundStyle(.white)

            if let project = projectService.remoteProjectState {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.orange)
                        Text(project.projectName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(project.totalFileCount) files")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("Scheme: \(project.activeScheme)  •  Target: \(project.activeTarget)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
            } else {
                Text("No active project reported from Mac.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var gitStateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Git Control")
                .font(.headline)
                .foregroundStyle(.white)

            if let project = projectService.remoteProjectState {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(project.activeBranch, systemImage: "arrow.triangle.branch")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.cyan)
                        Text(project.isGitDirty ? "Uncommitted Changes" : "Clean Working Tree")
                            .font(.caption)
                            .foregroundStyle(project.isGitDirty ? .orange : .green)
                    }
                    Spacer()

                    HStack(spacing: 12) {
                        VStack {
                            Text("↑ \(project.aheadCount)")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                            Text("Ahead")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        VStack {
                            Text("↓ \(project.behindCount)")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                            Text("Behind")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
            } else {
                Text("Git status unavailable.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var buildConsoleShortcutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Build & Diagnostics")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                NavigationLink("Open Console") {
                    RemoteBuildConsoleView()
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(.cyan)
            }

            if let build = buildService.activeBuild {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(build.state.rawValue.capitalized)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(build.state == .succeeded ? .green : (build.state == .failed ? .red : .orange))
                        Text(build.currentTaskName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(String(format: "%.0f%%", build.progressFraction * 100))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.cyan)
                }
                .padding(12)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
            } else {
                Button {
                    Task {
                        if let path = projectService.remoteProjectState?.projectPath,
                           let scheme = projectService.remoteProjectState?.activeScheme {
                            try? await buildService.requestBuild(projectPath: path, scheme: scheme)
                        }
                    }
                } label: {
                    Label("Trigger Remote Build", systemImage: "hammer.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var deviceMetricsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mac Hardware Metrics")
                .font(.headline)
                .foregroundStyle(.white)

            if let device = deviceService.remoteDeviceState {
                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
                    GridRow {
                        VStack(alignment: .leading) {
                            Text("CPU Usage")
                                .font(.caption).foregroundStyle(.secondary)
                            Text(String(format: "%.1f%%", device.cpuUsagePercentage))
                                .font(.subheadline.weight(.bold)).foregroundStyle(.white)
                        }
                        VStack(alignment: .leading) {
                            Text("Memory Usage")
                                .font(.caption).foregroundStyle(.secondary)
                            Text(String(format: "%.1f%%", device.memoryUsagePercentage))
                                .font(.subheadline.weight(.bold)).foregroundStyle(.white)
                        }
                    }
                    GridRow {
                        VStack(alignment: .leading) {
                            Text("OS Version")
                                .font(.caption).foregroundStyle(.secondary)
                            Text(device.osVersion)
                                .font(.subheadline.weight(.bold)).foregroundStyle(.white)
                        }
                        VStack(alignment: .leading) {
                            Text("Free Disk Space")
                                .font(.caption).foregroundStyle(.secondary)
                            Text(String(format: "%.0f GB", device.availableDiskSpaceGB))
                                .font(.subheadline.weight(.bold)).foregroundStyle(.white)
                        }
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
            } else {
                Text("Mac hardware metrics unavailable.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
