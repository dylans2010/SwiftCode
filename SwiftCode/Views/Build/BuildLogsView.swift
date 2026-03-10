import SwiftUI

struct BuildLogsView: View {
    @Environment(\.dismiss) private var dismiss

    let owner: String
    let repo: String

    @State private var logs: [BuildLogEntry] = []
    @State private var isLoading = false
    @State private var selectedRun: WorkflowRunInfo?

    struct BuildLogEntry: Identifiable {
        let id = UUID()
        let runNumber: Int
        let name: String
        let status: String
        let conclusion: String?
        let createdAt: Date
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView("Loading build logs...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if logs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary.opacity(0.5))
                        Text("No build logs available")
                            .foregroundStyle(.secondary)
                        if owner.isEmpty || repo.isEmpty {
                            Text("Connect a GitHub repository to view build logs")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(logs) { log in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Circle()
                                    .fill(colorForConclusion(log.conclusion))
                                    .frame(width: 8, height: 8)
                                Text("Build #\(log.runNumber)")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.white)
                                Spacer()
                                Text(log.status)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            HStack {
                                Text(log.name)
                                    .font(.caption)
                                Spacer()
                                Text(log.createdAt, style: .relative)
                                    .font(.caption2)
                            }
                            .foregroundStyle(.secondary)

                            if let conclusion = log.conclusion {
                                Text(conclusion.capitalized)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(colorForConclusion(log.conclusion).opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
                                    .foregroundStyle(colorForConclusion(log.conclusion))
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color(red: 0.10, green: 0.10, blue: 0.14))
            .navigationTitle("Build Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        loadLogs()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear { loadLogs() }
        }
    }

    private func colorForConclusion(_ conclusion: String?) -> Color {
        switch conclusion {
        case "success": return .green
        case "failure": return .red
        case "cancelled": return .yellow
        default: return .blue
        }
    }

    private func loadLogs() {
        guard !owner.isEmpty, !repo.isEmpty else { return }
        isLoading = true
        Task {
            do {
                let runs = try await GitHubService.shared.listWorkflowRuns(owner: owner, repo: repo)
                await MainActor.run {
                    logs = runs.prefix(20).map { run in
                        BuildLogEntry(
                            runNumber: run.runNumber,
                            name: run.name ?? "Workflow",
                            status: run.status,
                            conclusion: run.conclusion,
                            createdAt: run.createdAt
                        )
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}
