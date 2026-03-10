import SwiftUI

struct BuildStatusView: View {
    let owner: String
    let repo: String
    @Environment(\.dismiss) private var dismiss

    @State private var workflowRuns: [WorkflowRun] = []
    @State private var releases: [GitHubRelease] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var selectedRun: WorkflowRun?
    @State private var logsText: String?
    @State private var showLogs = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.10, green: 0.10, blue: 0.14).ignoresSafeArea()

                if owner.isEmpty || repo.isEmpty {
                    noRepoView
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            workflowRunsSection
                            releasesSection
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Build Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        loadData()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
            .alert("Error", isPresented: $showError, presenting: errorMessage) { _ in
                Button("OK") {}
            } message: { msg in Text(msg) }
            .sheet(isPresented: $showLogs) {
                logsSheet
            }
            .onAppear { loadData() }
        }
    }

    // MARK: - Subviews

    private var noRepoView: some View {
        VStack(spacing: 16) {
            Image(systemName: "link.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Repository Connected")
                .font(.title3)
                .foregroundStyle(.white)
            Text("Connect a GitHub repository in the GitHub integration panel to view build status.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var workflowRunsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Workflow Runs", systemImage: "hammer.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                if isLoading {
                    ProgressView().scaleEffect(0.8)
                }
            }

            VStack(spacing: 8) {
                if workflowRuns.isEmpty && !isLoading {
                    Text("No workflow runs found")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    ForEach(workflowRuns.prefix(10)) { run in
                        BuildRunCard(run: run) {
                            selectedRun = run
                            loadLogs(for: run)
                        }
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var releasesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Releases", systemImage: "shippingbox.fill")
                .font(.headline)
                .foregroundStyle(.white)

            VStack(spacing: 8) {
                if releases.isEmpty && !isLoading {
                    Text("No releases yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    ForEach(releases.prefix(5)) { release in
                        ReleaseRow(release: release)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var logsSheet: some View {
        NavigationStack {
            ScrollView {
                if let logs = logsText {
                    Text(logs)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color(red: 0.85, green: 0.85, blue: 0.85))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ProgressView("Loading logs...")
                        .padding()
                }
            }
            .background(Color(red: 0.11, green: 0.11, blue: 0.14))
            .navigationTitle("Build Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { showLogs = false }
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Actions

    private func loadData() {
        guard !owner.isEmpty, !repo.isEmpty else { return }
        isLoading = true
        Task {
            async let runs = (try? GitHubService.shared.listWorkflowRuns(owner: owner, repo: repo)) ?? []
            async let rels = (try? GitHubService.shared.listReleases(owner: owner, repo: repo)) ?? []
            let (r, l) = await (runs, rels)
            await MainActor.run {
                workflowRuns = r
                releases = l
                isLoading = false
            }
        }
    }

    private func loadLogs(for run: WorkflowRun) {
        logsText = nil
        showLogs = true
        Task {
            do {
                let logsURL = try await GitHubService.shared.getWorkflowRunLogsURL(
                    owner: owner,
                    repo: repo,
                    runID: run.id
                )
                let (data, _) = try await URLSession.shared.data(from: logsURL)
                let text = String(data: data, encoding: .utf8) ?? "Unable to decode logs."
                await MainActor.run { logsText = text }
            } catch {
                await MainActor.run {
                    logsText = "Error loading logs: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Build Run Card

struct BuildRunCard: View {
    let run: WorkflowRun
    let onViewLogs: () -> Void

    var statusColor: Color {
        switch run.conclusion ?? run.status {
        case "success": return .green
        case "failure": return .red
        case "cancelled": return .gray
        case "in_progress": return .yellow
        default: return .secondary
        }
    }

    var statusLabel: String {
        (run.conclusion ?? run.status).replacingOccurrences(of: "_", with: " ").capitalized
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 36, height: 36)
                if run.isRunning {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(statusColor)
                } else {
                    Image(systemName: run.statusBadge)
                        .foregroundStyle(statusColor)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(run.name ?? "Build #\(run.runNumber)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(statusLabel)
                        .font(.caption)
                        .foregroundStyle(statusColor)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(run.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                onViewLogs()
            } label: {
                Text("Logs")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.08), in: Capsule())
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Release Row

struct ReleaseRow: View {
    let release: GitHubRelease

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "tag.fill")
                .foregroundStyle(.purple)

            VStack(alignment: .leading, spacing: 4) {
                Text(release.name ?? release.tagName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                Text(release.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Download IPA if available
            if let ipaAsset = release.assets.first(where: { $0.name.hasSuffix(".ipa") }) {
                Link(destination: URL(string: ipaAsset.browserDownloadUrl)!) {
                    Label("IPA", systemImage: "arrow.down.circle.fill")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.orange.opacity(0.3), in: Capsule())
                        .foregroundStyle(.orange)
                }
            }

            Link(destination: URL(string: release.htmlUrl)!) {
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.blue)
                    .font(.caption)
            }
        }
        .padding(12)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
    }
}
