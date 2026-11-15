import AppKit
import YcodeDeviceModel
import SwiftUI

public struct DeviceConsoleFileExport {
    public static func save(text: String, suggestedName: String) -> String? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}

public struct DeviceConnectConsole: View {
    @State private var consoleManager = ConsoleManager.shared
    @State private var searchText = ""
    @State private var filterSeverity: DeviceLog.Severity? = nil
    @State private var exportError: String? = nil

    public init() {}

    private var filteredLogs: [DeviceLog] {
        consoleManager.visibleLogs(searchText: searchText, severity: filterSeverity)
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Console Output", selection: $consoleManager.selectedConsoleTab) {
                    Text("Build Compiler").tag(0)
                    Text("Device System Logs").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 250)

                Spacer()

                TextField("Search", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)

                Picker("Severity", selection: $filterSeverity) {
                    Text("All").tag(nil as DeviceLog.Severity?)
                    Text("Info").tag(DeviceLog.Severity.info as DeviceLog.Severity?)
                    Text("Warnings").tag(DeviceLog.Severity.warning as DeviceLog.Severity?)
                    Text("Errors").tag(DeviceLog.Severity.error as DeviceLog.Severity?)
                }
                .frame(width: 150)

                Button(action: {
                    if consoleManager.isPaused {
                        consoleManager.resume()
                    } else {
                        consoleManager.pause()
                    }
                }) {
                    Label(consoleManager.isPaused ? "Resume" : "Pause", systemImage: consoleManager.isPaused ? "play.fill" : "pause.fill")
                }
                .buttonStyle(.bordered)
                .help(consoleManager.isPaused ? "Resume appending new log lines" : "Pause appending new log lines; incoming lines are buffered")

                Button(action: {
                    let text = consoleManager.exportText(searchText: searchText, severity: filterSeverity)
                    if let error = DeviceConsoleFileExport.save(text: text, suggestedName: "device-connect-logs.txt") {
                        exportError = "Export failed: \(error)"
                    } else {
                        exportError = nil
                    }
                }) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .help("Write the currently filtered log lines to a file")

                Button(action: {
                    let logsText = DeviceConnectConsoleManager.formattedText(filteredLogs)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(logsText, forType: .string)
                }) {
                    Label("Copy Logs", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .help("Copy all visible console logs to clipboard")

                Button(action: { consoleManager.clearLogs() }) {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)

                if filteredLogs.contains(where: { $0.severity == .error }) {
                    Button {
                        let logText = filteredLogs.map { $0.message }.joined(separator: "\n")
                        AssistNavigationRouter.openAssistWithNewSession(prompt: "Diagnose and fix the Device Connect deployment failure. Verify device installation, simctl commands, and build products. Logs:\n\(logText)")
                    } label: {
                        Label("Fix with Assist", systemImage: "sparkles")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(10)
            .liquidGlass(style: .standard, cornerRadius: 0)

            if consoleManager.isPaused {
                Text("Paused — incoming log lines are buffered and will appear on Resume.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
            }

            if let exportError {
                Text(exportError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
            }

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(filteredLogs) { log in
                            HStack(alignment: .top, spacing: 6) {
                                Text("[\(formattedTime(log.timestamp))]")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)

                                if !log.category.isEmpty {
                                    Text("[\(log.category)]")
                                        .font(.system(.caption, design: .monospaced).weight(.bold))
                                        .foregroundStyle(.blue)
                                }

                                Text(log.message)
                                    .font(.system(.subheadline, design: .monospaced))
                                    .foregroundStyle(logColor(log.severity))
                            }
                            .id(log.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: filteredLogs.count) { _, _ in
                    if !consoleManager.isPaused, let last = filteredLogs.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .background(Color(NSColor.textBackgroundColor))
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }

    private func logColor(_ severity: DeviceLog.Severity) -> Color {
        switch severity {
        case .error: return .red
        case .warning: return .orange
        case .debug: return .secondary
        case .info: return .primary
        }
    }
}
