import SwiftUI

struct LogConsoleView: View {
    @StateObject private var logger = InternalLoggingManager.shared
    @State private var searchText = ""
    @State private var selectedLevels: Set<LogLevel> = Set(LogLevel.allCases)
    @State private var selectedCategories: Set<LogCategory> = Set(LogCategory.allCases)

    var filteredLogs: [LogEntry] {
        logger.logs.filter { entry in
            let matchesSearch = searchText.isEmpty ||
                               entry.message.localizedCaseInsensitiveContains(searchText) ||
                               entry.category.rawValue.localizedCaseInsensitiveContains(searchText)
            let matchesLevel = selectedLevels.contains(entry.level)
            let matchesCategory = selectedCategories.contains(entry.category)
            return matchesSearch && matchesLevel && matchesCategory
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar

            List(filteredLogs.reversed()) { log in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        levelBadge(log.level)

                        Text(log.category.rawValue)
                            .font(.caption.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(categoryColor(log.category).opacity(0.2))
                            .foregroundStyle(categoryColor(log.category))
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                        Spacer()

                        Text(log.timestamp, style: .time)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Text(log.message)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
                .padding(.vertical, 4)
            }
            .listStyle(.plain)
        }
        .navigationTitle("Log Console")
        .searchable(text: $searchText, prompt: "Filter logs")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        logger.clearLogs()
                    } label: {
                        Label("Clear Logs", systemImage: "trash")
                    }

                    ShareLink(item: logger.exportLogs()) {
                        Label("Export Logs", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    ForEach(LogLevel.allCases) { level in
                        Toggle(level.rawValue, isOn: Binding(
                            get: { selectedLevels.contains(level) },
                            set: { isOn in
                                if isOn { selectedLevels.insert(level) }
                                else { selectedLevels.remove(level) }
                            }
                        ))
                    }
                } label: {
                    Label("Levels", systemImage: "line.3.horizontal.decrease.circle")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                }

                Menu {
                    ForEach(LogCategory.allCases) { category in
                        Toggle(category.rawValue, isOn: Binding(
                            get: { selectedCategories.contains(category) },
                            set: { isOn in
                                if isOn { selectedCategories.insert(category) }
                                else { selectedCategories.remove(category) }
                            }
                        ))
                    }
                } label: {
                    Label("Categories", systemImage: "tag")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(UIColor.secondarySystemBackground))
    }

    @ViewBuilder
    private func levelBadge(_ level: LogLevel) -> some View {
        Text(level.rawValue)
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(levelColor(level))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    private func levelColor(_ level: LogLevel) -> Color {
        switch level {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }

    private func categoryColor(_ category: LogCategory) -> Color {
        switch category {
        case .networking: return .blue
        case .githubAPI: return .purple
        case .deployments: return .green
        case .aiProcessing: return .orange
        case .storeKit: return .yellow
        case .extensions: return .cyan
        case .buildSystem: return .red
        case .general: return .gray
        }
    }
}
