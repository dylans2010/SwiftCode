import SwiftUI

public struct AssistSettingsView: View {
    @AppStorage("assist.safetyLevel") private var safetyLevel = AssistSafetyLevel.balanced.rawValue
    @AppStorage("assist.isAutonomous") private var isAutonomous = true
    @AppStorage("assist.debugMode") private var debugMode = false

    @StateObject private var manager = AssistManager.shared

    public var body: some View {
        Form {
            Section {
                Toggle("Autonomous Execution", isOn: $isAutonomous)
                Picker("Safety Level", selection: $safetyLevel) {
                    ForEach(AssistSafetyLevel.allCases, id: \.rawValue) { level in
                        Text(level.rawValue).tag(level.rawValue)
                    }
                }
            } header: {
                Text("Execution Mode")
            } footer: {
                Text("In autonomous mode, the agent will execute plans without requesting confirmation for each step.")
            }

            Section {
                Toggle("Debug Mode", isOn: $debugMode)
                if debugMode {
                    NavigationLink("View Tool Logs") {
                        AssistLogsDetailView(logger: manager.logger)
                    }
                }
            } header: {
                Text("Developer")
            }

            Section("Available Tools") {
                ForEach(manager.registry.allTools, id: \.id) { tool in
                    VStack(alignment: .leading) {
                        Text(tool.name).font(.headline)
                        Text(tool.description).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Assist Settings")
    }
}

struct AssistLogsDetailView: View {
    @ObservedObject var logger: AssistLogger

    var body: some View {
        List(logger.logs) { entry in
            VStack(alignment: .leading) {
                HStack {
                    Text(entry.level.rawValue)
                        .font(.caption2.bold())
                        .padding(4)
                        .background(color(for: entry.level))
                        .clipShape(Capsule())

                    if let toolId = entry.toolId {
                        Text("[\(toolId)]").font(.caption2).monospaced()
                    }

                    Spacer()
                    Text(entry.timestamp, style: .time).font(.caption2).foregroundStyle(.secondary)
                }
                Text(entry.message).font(.subheadline)
            }
        }
        .navigationTitle("Assist Logs")
    }

    private func color(for level: AssistLogLevel) -> Color {
        switch level {
        case .info: return .blue.opacity(0.2)
        case .warning: return .orange.opacity(0.2)
        case .error: return .red.opacity(0.2)
        case .debug: return .gray.opacity(0.2)
        }
    }
}
