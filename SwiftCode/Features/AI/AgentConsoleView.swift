import SwiftUI

struct AgentConsoleView: View {
    @StateObject private var logger = AgentLogger.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Agent Tool Execution Logs")
                    .font(.headline)
                Spacer()
                Button("Clear") {
                    logger.toolLogs.removeAll()
                }
                .font(.caption)
            }
            .padding()
            .background(Color.secondary.opacity(0.1))

            List {
                if logger.toolLogs.isEmpty {
                    Text("No tool calls recorded.")
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    ForEach(logger.toolLogs) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("[\(entry.source.rawValue)]")
                                    .font(.caption.bold())
                                    .foregroundStyle(sourceColor(entry.source))
                                Text(entry.toolName)
                                    .font(.system(.subheadline, design: .monospaced))
                                Spacer()
                                Text(String(format: "%.3fs", entry.duration))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            if let error = entry.error {
                                Text("Error: \(error)")
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                            } else {
                                Text("Arguments: \(formatArgs(entry.arguments))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    private func sourceColor(_ source: ToolSource) -> Color {
        switch source {
        case .core: return .blue
        case .skill: return .purple
        case .connection: return .orange
        case .plugin: return .green
        }
    }

    private func formatArgs(_ args: [String: Any]) -> String {
        return args.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
    }
}
