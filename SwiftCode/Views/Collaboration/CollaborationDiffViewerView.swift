import SwiftUI

struct CollaborationDiffViewerView: View {
    let diff: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(diff.components(separatedBy: .newlines).enumerated()), id: \.offset) { _, line in
                    lineView(line)
                }
            }
            .font(.system(.caption, design: .monospaced))
            .padding()
        }
        .background(Color(.systemGray6))
        .navigationTitle("Diff Viewer")
    }

    @ViewBuilder
    private func lineView(_ line: String) -> some View {
        HStack(spacing: 8) {
            if line.hasPrefix("+") {
                Text("+").foregroundStyle(.green)
                Text(line.dropFirst()).foregroundStyle(.primary)
            } else if line.hasPrefix("-") {
                Text("-").foregroundStyle(.red)
                Text(line.dropFirst()).foregroundStyle(.primary)
            } else {
                Text(" ").foregroundStyle(.secondary)
                Text(line).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 4)
        .background(lineColor(line))
    }

    private func lineColor(_ line: String) -> Color {
        if line.hasPrefix("+") { return .green.opacity(0.15) }
        if line.hasPrefix("-") { return .red.opacity(0.15) }
        return .clear
    }
}

struct DiffViewerTestView: View {
    @ObservedObject var manager: CollaborationManager

    var body: some View {
        List {
            Section("Recent Commit Diff") {
                if let lastCommit = manager.commits.commits.first {
                    NavigationLink(lastCommit.message) {
                        CollaborationDiffViewerView(diff: lastCommit.changes.values.first ?? "No diff available")
                    }
                } else {
                    Text("No commits yet.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Diffs")
    }
}
