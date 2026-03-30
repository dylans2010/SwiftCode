import SwiftUI

struct ConsoleCommandView: View {
    @State private var commandInput = ""
    @State private var commandOutput: [String] = ["SwiftCode Debug Shell v1.0", "Type 'help' for available commands."]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(0..<commandOutput.count, id: \.self) { i in
                        Text(commandOutput[i])
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(commandOutput[i].hasPrefix(">") ? .green : .white)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .background(Color.black)

            HStack {
                Text(">")
                    .foregroundStyle(.green)
                    .font(.system(.body, design: .monospaced))
                TextField("Enter command...", text: $commandInput)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit {
                        executeCommand()
                    }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
        }
        .navigationTitle("Console")
    }

    private func executeCommand() {
        let cmd = commandInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cmd.isEmpty else { return }

        commandOutput.append("> \(cmd)")

        switch cmd.lowercased() {
        case "help":
            commandOutput.append("Available commands: help, clear, info, ping, storage-stats, logout")
        case "clear":
            commandOutput = []
        case "info":
            commandOutput.append("SwiftCode build 2024.1.0")
            commandOutput.append("Device: \(UIDevice.current.name)")
        case "ping":
            commandOutput.append("Pong! (12ms)")
        case "storage-stats":
            commandOutput.append("Disk space: 24GB free")
            commandOutput.append("App size: 45MB")
        default:
            commandOutput.append("Error: Command '\(cmd)' not found.")
        }

        commandInput = ""
    }
}
