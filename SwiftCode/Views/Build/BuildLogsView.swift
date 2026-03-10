import SwiftUI

// MARK: - Structured Log Entry

struct StructuredLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let category: LogCategory
    let message: String
    let detail: String?

    enum LogLevel: String, CaseIterable {
        case info = "Info"
        case warning = "Warning"
        case error = "Error"
        case debug = "Debug"

        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            case .debug: return "ant.fill"
            }
        }

        var color: Color {
            switch self {
            case .info: return .blue
            case .warning: return .yellow
            case .error: return .red
            case .debug: return .secondary
            }
        }
    }

    enum LogCategory: String, CaseIterable {
        case build = "Build"
        case fileEdit = "File Edit"
        case dependency = "Dependency"
        case agent = "Agent"
        case system = "System"

        var icon: String {
            switch self {
            case .build: return "hammer.fill"
            case .fileEdit: return "doc.text.fill"
            case .dependency: return "shippingbox.fill"
            case .agent: return "sparkles"
            case .system: return "gear"
            }
        }
    }
}

// MARK: - Build Log Manager

@MainActor
final class BuildLogManager: ObservableObject {
    static let shared = BuildLogManager()
    @Published var entries: [StructuredLogEntry] = []

    private init() {}

    func log(_ message: String, level: StructuredLogEntry.LogLevel = .info,
             category: StructuredLogEntry.LogCategory = .system, detail: String? = nil) {
        let entry = StructuredLogEntry(
            timestamp: Date(),
            level: level,
            category: category,
            message: message,
            detail: detail
        )
        entries.append(entry)
    }

    func clear() {
        entries = []
    }
}

// MARK: - Build Logs View

struct BuildLogsView: View {
    @Environment(\.dismiss) private var dismiss

    let owner: String
    let repo: String

    @StateObject private var logManager = BuildLogManager.shared
    @State private var logs: [BuildLogEntry] = []
    @State private var isLoading = false
    @State private var selectedRun: WorkflowRunInfo?
    @State private var filterLevel: StructuredLogEntry.LogLevel?

    struct WorkflowRunInfo {
        let runNumber: Int
        let name: String?
        let status: String
        let conclusion: String?
        let createdAt: Date
    }

    struct BuildLogEntry: Identifiable {
        let id = UUID()
        let runNumber: Int
        let name: String
        let status: String
        let conclusion: String?
        let createdAt: Date
    }

    private var filteredLocalLogs: [StructuredLogEntry] {
        guard let level = filterLevel else { return logManager.entries }
        return logManager.entries.filter { $0.level == level }
    }

    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        levelFilterButton(nil, label: "All")
                        ForEach(StructuredLogEntry.LogLevel.allCases, id: \.rawValue) { level in
                            levelFilterButton(level, label: level.rawValue)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }

                Divider().opacity(0.3)

                if isLoading {
                    ProgressView("Loading Build Logs...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredLocalLogs.isEmpty && logs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary.opacity(0.5))
                        Text("No Build Logs Available")
                            .foregroundStyle(.secondary)
                        if owner.isEmpty || repo.isEmpty {
                            Text("Connect a GitHub repository to view build logs")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        // Structured local logs
                        if !filteredLocalLogs.isEmpty {
                            Section("Local Logs") {
                                ForEach(filteredLocalLogs.reversed()) { entry in
                                    structuredLogRow(entry)
                                }
                            }
                        }

                        // Remote CI logs
                        if !logs.isEmpty {
                            Section("CI Builds") {
                                ForEach(logs) { log in
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
                            }
                        }
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

    private func structuredLogRow(_ entry: StructuredLogEntry) -> some View {
        HStack(spacing: 8) {
            Image(systemName: entry.level.icon)
                .foregroundStyle(entry.level.color)
                .font(.system(size: 12))
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(Self.timestampFormatter.string(from: entry.timestamp))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("[\(entry.category.rawValue)]")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(entry.level.color)
                }
                Text(entry.message)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(3)
                if let detail = entry.detail {
                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }

    private func levelFilterButton(_ level: StructuredLogEntry.LogLevel?, label: String) -> some View {
        Button {
            filterLevel = level
        } label: {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    filterLevel == level
                        ? Color.orange.opacity(0.3)
                        : Color.white.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 6)
                )
                .foregroundStyle(filterLevel == level ? .orange : .secondary)
        }
        .buttonStyle(.plain)
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
