import SwiftUI

struct ErrorDiagnosticsView: View {
    @EnvironmentObject private var projectManager: ProjectManager
    @State private var logs = ""

    private var diagnostics: [BuildDiagnostic] {
        logs.split(separator: "\n").compactMap { BuildDiagnostic(line: String($0)) }
    }

    var body: some View {
        NavigationStack {
            VStack {
                TextField("Paste compile/runtime errors", text: $logs, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .padding()

                List(diagnostics) { item in
                    Button {
                        if let node = projectManager.activeProject?.files.flatMapDeep().first(where: { $0.path.contains(item.file) }) {
                            projectManager.openFile(node)
                        }
                    } label: {
                        VStack(alignment: .leading) {
                            Text("\(item.file):\(item.line)").font(.headline)
                            Text(item.message).font(.subheadline)
                            Text(item.explanation).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Error Diagnostics")
        }
    }
}

private struct BuildDiagnostic: Identifiable {
    let id = UUID()
    let file: String
    let line: Int
    let message: String
    let explanation: String

    init?(line: String) {
        let parts = line.split(separator: ":")
        guard parts.count >= 3, let lineNo = Int(parts[1]) else { return nil }
        file = String(parts[0]); self.line = lineNo
        message = parts.dropFirst(2).joined(separator: ":")
        explanation = "Likely type mismatch, missing symbol, or invalid call signature."
    }
}

private extension Array where Element == FileNode {
    func flatMapDeep() -> [FileNode] {
        flatMap { node in
            node.isDirectory ? [node] + node.children.flatMapDeep() : [node]
        }
    }
}
