import SwiftUI

// MARK: - Terminal View

struct TerminalView: View {
    @EnvironmentObject private var projectManager: ProjectManager
    @State private var commandInput = ""
    @State private var outputLines: [TerminalLine] = [
        TerminalLine(text: "SwiftCode Terminal — type 'help' for available commands", type: .info)
    ]
    @State private var commandHistory: [String] = []
    @State private var historyIndex = -1
    @State private var isRunning = false
    @FocusState private var inputFocused: Bool

    struct TerminalLine: Identifiable {
        let id = UUID()
        var text: String
        var type: LineType
        enum LineType { case command, output, error, info }
        var color: Color {
            switch type {
            case .command: return .cyan
            case .output:  return Color(red: 0.85, green: 0.85, blue: 0.85)
            case .error:   return .red
            case .info:    return .green
            }
        }
    }

    private let supportedCommands = [
        "help", "clear", "git status", "git pull", "git log",
        "swift build", "swift package update", "swift package resolve",
        "ls", "pwd", "cat Package.swift"
    ]

    var body: some View {
        VStack(spacing: 0) {
            terminalHeader
            Divider().opacity(0.3)
            outputArea
            Divider().opacity(0.3)
            inputBar
        }
        .background(Color(red: 0.06, green: 0.07, blue: 0.10))
        .onAppear { inputFocused = true }
    }

    // MARK: - Header

    private var terminalHeader: some View {
        HStack(spacing: 8) {
            Circle().fill(.red).frame(width: 10, height: 10)
            Circle().fill(.yellow).frame(width: 10, height: 10)
            Circle().fill(.green).frame(width: 10, height: 10)
            Spacer()
            Text(projectManager.activeProject?.name ?? "Terminal")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                outputLines = [TerminalLine(text: "Cleared.", type: .info)]
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(red: 0.10, green: 0.10, blue: 0.14))
    }

    // MARK: - Output Area

    private var outputArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(outputLines) { line in
                        HStack(alignment: .top, spacing: 4) {
                            if line.type == .command {
                                Text("❯")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(.cyan)
                            }
                            Text(line.text)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(line.color)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 1)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.vertical, 8)
            }
            .onChange(of: outputLines.count) {
                withAnimation { proxy.scrollTo("bottom") }
            }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 8) {
            Text("❯")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.cyan)

            TextField("", text: $commandInput)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.white)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($inputFocused)
                .onSubmit { runCommand() }
                .onChange(of: commandInput) { oldVal, newVal in
                    historyIndex = -1
                }

            if isRunning {
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(.green)
            } else {
                Button {
                    runCommand()
                } label: {
                    Image(systemName: "return")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(commandInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(red: 0.08, green: 0.08, blue: 0.12))
    }

    // MARK: - Command Execution

    private func runCommand() {
        let cmd = commandInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cmd.isEmpty else { return }

        commandHistory.insert(cmd, at: 0)
        commandInput = ""
        historyIndex = -1

        outputLines.append(TerminalLine(text: cmd, type: .command))

        Task {
            await executeCommand(cmd)
        }
    }

    @MainActor
    private func executeCommand(_ cmd: String) async {
        isRunning = true
        defer { isRunning = false }

        let projectDir = projectManager.activeProject?.directoryURL

        switch cmd.lowercased() {
        case "help":
            let helpText = """
Available commands:
  help                   Show this help
  clear                  Clear terminal output
  ls                     List project files
  pwd                    Show project directory
  cat Package.swift      Show Package.swift
  git status             Show git working tree status
  git pull               Pull latest changes
  git log                Show recent commits
  swift build            Trigger a Swift build note
  swift package update   Update package dependencies
  swift package resolve  Resolve package graph
"""
            addOutput(helpText, type: .output)

        case "clear":
            outputLines = [TerminalLine(text: "Cleared.", type: .info)]

        case "pwd":
            if let dir = projectDir {
                addOutput(dir.path, type: .output)
            } else {
                addOutput("No project open.", type: .error)
            }

        case "ls":
            if let project = projectManager.activeProject {
                let names = project.files.map { ($0.isDirectory ? "📁 " : "📄 ") + $0.name }
                addOutput(names.isEmpty ? "(empty)" : names.joined(separator: "\n"), type: .output)
            } else {
                addOutput("No project open.", type: .error)
            }

        case "cat package.swift":
            if let dir = projectDir {
                let url = dir.appendingPathComponent("Package.swift")
                if let content = try? String(contentsOf: url, encoding: .utf8) {
                    addOutput(content, type: .output)
                } else {
                    addOutput("Package.swift not found in project root.", type: .error)
                }
            } else {
                addOutput("No project open.", type: .error)
            }

        case "git status":
            addInfo("Simulated git status:")
            addOutput("On branch main\nYour branch is up to date with 'origin/main'.\nnothing to commit, working tree clean", type: .output)

        case "git pull":
            addInfo("Simulated git pull:")
            await simulateDelay(0.8)
            addOutput("Already up to date.", type: .output)

        case "git log":
            addInfo("Recent commits (simulated):")
            addOutput("""
commit a1b2c3d (HEAD -> main, origin/main)
Author: Developer <dev@example.com>
Date:   Mon Jan 6 10:00:00 2025

    Latest changes

commit f4e5d6c
Author: Developer <dev@example.com>
Date:   Sun Jan 5 18:30:00 2025

    Initial commit
""", type: .output)

        case "swift build":
            addInfo("Swift build is handled via GitHub Actions in this environment.")
            addOutput("Use the Build Status panel to trigger and monitor builds.", type: .info)

        case "swift package update":
            addInfo("Updating Swift package dependencies...")
            await simulateDelay(1.0)
            addOutput("Package update complete. Use Dependency Manager to manage packages.", type: .output)

        case "swift package resolve":
            addInfo("Resolving Swift package graph...")
            await simulateDelay(0.6)
            addOutput("Package resolution complete.", type: .output)

        default:
            if cmd.hasPrefix("git ") {
                addOutput("git: '\(cmd.dropFirst(4))' is not a supported git command.", type: .error)
            } else {
                addOutput("Command not found: \(cmd). Type 'help' for available commands.", type: .error)
            }
        }
    }

    private func addOutput(_ text: String, type: TerminalLine.LineType) {
        for line in text.components(separatedBy: "\n") {
            outputLines.append(TerminalLine(text: line, type: type))
        }
    }

    private func addInfo(_ text: String) {
        outputLines.append(TerminalLine(text: text, type: .info))
    }

    private func simulateDelay(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
