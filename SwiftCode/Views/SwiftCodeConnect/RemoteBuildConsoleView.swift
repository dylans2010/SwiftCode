import SwiftUI

struct RemoteBuildConsoleView: View {
    @StateObject private var buildService = ConnectBuildService.shared
    @StateObject private var projectService = ConnectProjectService.shared

    @State private var selectedSeverityFilter: DiagnosticSeverity?

    var filteredDiagnostics: [RemoteBuildDiagnosticPayload] {
        guard let filter = selectedSeverityFilter else { return buildService.diagnostics }
        return buildService.diagnostics.filter { $0.severity == filter }
    }

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

            VStack(spacing: 16) {
                buildStatusHeader

                severityFilterBar

                diagnosticListView
            }
            .padding()
        }
        .navigationTitle("Remote Build Console")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink("Live Logs") {
                    RemoteLogStreamView()
                }
            }
        }
    }

    private var buildStatusHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let build = buildService.activeBuild {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Status: \(build.state.rawValue.capitalized)")
                            .font(.headline)
                            .foregroundStyle(statusColor(for: build.state))

                        Text(build.currentTaskName)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }
                    Spacer()

                    if build.state == .building || build.state == .preparing {
                        Button("Cancel") {
                            Task { try? await buildService.cancelBuild() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.small)
                    }
                }

                ProgressView(value: build.progressFraction)
                    .tint(.cyan)

                HStack {
                    Text("Errors: \(build.errorCount)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(build.errorCount > 0 ? .red : .secondary)
                    Text("Warnings: \(build.warningCount)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(build.warningCount > 0 ? .orange : .secondary)
                    Spacer()
                    Text(String(format: "%.1fs", build.elapsedTimeSeconds))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No active build running")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Ready to send build command to Mac.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()

                    Button("Start Build") {
                        Task {
                            if let path = projectService.remoteProjectState?.projectPath,
                               let scheme = projectService.remoteProjectState?.activeScheme {
                                try? await buildService.requestBuild(projectPath: path, scheme: scheme)
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func statusColor(for state: RemoteBuildState) -> Color {
        switch state {
        case .preparing, .building: return .orange
        case .succeeded: return .green
        case .failed: return .red
        case .cancelled: return .gray
        }
    }

    private var severityFilterBar: some View {
        HStack(spacing: 10) {
            Button {
                selectedSeverityFilter = nil
            } label: {
                Text("All (\(buildService.diagnostics.count))")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(selectedSeverityFilter == nil ? Color.cyan.opacity(0.3) : Color.white.opacity(0.05), in: Capsule())
                    .foregroundStyle(.white)
            }

            ForEach(DiagnosticSeverity.allCases, id: \.self) { severity in
                let count = buildService.diagnostics.filter { $0.severity == severity }.count
                Button {
                    selectedSeverityFilter = severity
                } label: {
                    Text("\(severity.rawValue.capitalized) (\(count))")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedSeverityFilter == severity ? Color.cyan.opacity(0.3) : Color.white.opacity(0.05), in: Capsule())
                        .foregroundStyle(severityColor(severity))
                }
            }
            Spacer()
        }
    }

    private func severityColor(_ severity: DiagnosticSeverity) -> Color {
        switch severity {
        case .error: return .red
        case .warning: return .orange
        case .note: return .blue
        }
    }

    private var diagnosticListView: some View {
        VStack(alignment: .leading, spacing: 10) {
            if filteredDiagnostics.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.green)
                    Text("No compiler diagnostics reported.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(32)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredDiagnostics) { diagnostic in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(severityColor(diagnostic.severity))
                                        .frame(width: 8, height: 8)

                                    Text(diagnostic.severity.rawValue.uppercaseString)
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(severityColor(diagnostic.severity))

                                    if let file = diagnostic.filePath {
                                        Text(file)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }

                                    if let line = diagnostic.line {
                                        Text(":\(line)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Text(diagnostic.message)
                                    .font(.subheadline)
                                    .foregroundStyle(.white)

                                if let code = diagnostic.code {
                                    Text(code)
                                        .font(.system(.caption, design: .monospaced))
                                        .padding(8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                                }
                            }
                            .padding(12)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
        }
    }
}
