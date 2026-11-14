import SwiftUI
import YcodeAssistant
import SwiftCodeGitHub
import SwiftCodeSDK
import YcodeIDECore
import YcodeIDEShell

@MainActor
struct GitDiffView: View {
    let hunks: [GitDiffHunk]
    @State private var collapsedFiles: Set<String> = []

    struct FileDiffGroup: Identifiable {
        let id: String
        let filePath: String
        let hunks: [GitDiffHunk]

        var addedCount: Int {
            hunks.reduce(0) { total, hunk in
                total + hunk.lines.filter { $0.hasPrefix("+") && !$0.hasPrefix("+++") }.count
            }
        }

        var removedCount: Int {
            hunks.reduce(0) { total, hunk in
                total + hunk.lines.filter { $0.hasPrefix("-") && !$0.hasPrefix("---") }.count
            }
        }
    }

    private var fileGroups: [FileDiffGroup] {
        var groups: [FileDiffGroup] = []
        var currentPath = ""
        var currentHunks: [GitDiffHunk] = []

        for hunk in hunks {
            let path = extractPath(from: hunk)
            if path == currentPath {
                currentHunks.append(hunk)
            } else {
                if !currentHunks.isEmpty {
                    groups.append(FileDiffGroup(id: currentPath, filePath: currentPath, hunks: currentHunks))
                }
                currentPath = path
                currentHunks = [hunk]
            }
        }
        if !currentHunks.isEmpty {
            groups.append(FileDiffGroup(id: currentPath, filePath: currentPath, hunks: currentHunks))
        }
        return groups
    }

    private func extractPath(from hunk: GitDiffHunk) -> String {
        if let path = hunk.filePath, !path.isEmpty { return path }
        if hunk.header.contains("a/") && hunk.header.contains("b/") {
            let parts = hunk.header.components(separatedBy: " ")
            if let bPart = parts.first(where: { $0.hasPrefix("b/") }) {
                return String(bPart.dropFirst(2))
            }
        }
        for line in hunk.lines {
            if line.hasPrefix("+++ b/") {
                return String(line.dropFirst(6))
            } else if line.hasPrefix("diff --git ") {
                let parts = line.components(separatedBy: " ")
                if parts.count >= 4 {
                    var p = parts[3]
                    if p.hasPrefix("b/") { p = String(p.dropFirst(2)) }
                    return p
                }
            }
        }
        return "Changes"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("File Change Diff Viewer", systemImage: "doc.text.magnifyingglass")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                if !fileGroups.isEmpty {
                    HStack(spacing: 8) {
                        Button("Expand All") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                collapsedFiles.removeAll()
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("Collapse All") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                collapsedFiles = Set(fileGroups.map(\.filePath))
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            .padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 16) {
                    if fileGroups.isEmpty {
                        GroupBox {
                            ContentUnavailableView(
                                "No Changes Detected",
                                systemImage: "doc.text",
                                description: Text("There are no staged or unstaged diffs to view.")
                            )
                            .frame(height: 150)
                            .padding()
                        }
                        .groupBoxStyle(ModernGroupBoxStyle())
                    } else {
                        ForEach(fileGroups) { group in
                            GroupBox {
                                VStack(alignment: .leading, spacing: 0) {
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            if collapsedFiles.contains(group.filePath) {
                                                collapsedFiles.remove(group.filePath)
                                            } else {
                                                collapsedFiles.insert(group.filePath)
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: collapsedFiles.contains(group.filePath) ? "chevron.right" : "chevron.down")
                                                .font(.caption2.bold())
                                                .foregroundStyle(.secondary)
                                                .frame(width: 14)

                                            Image(systemName: "doc.text")
                                                .foregroundStyle(Color.accentColor)

                                            Text(group.filePath)
                                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                                .foregroundStyle(.primary)
                                                .lineLimit(1)

                                            Spacer()

                                            if group.addedCount > 0 {
                                                Text("+\(group.addedCount)")
                                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                    .foregroundStyle(.secondary)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.secondary.opacity(0.12))
                                                    .cornerRadius(4)
                                            }

                                            if group.removedCount > 0 {
                                                Text("-\(group.removedCount)")
                                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                    .foregroundStyle(.secondary)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.secondary.opacity(0.12))
                                                    .cornerRadius(4)
                                            }
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 8)
                                        .background(Color.secondary.opacity(0.04))
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    if !collapsedFiles.contains(group.filePath) {
                                        Divider()

                                        VStack(alignment: .leading, spacing: 0) {
                                            ForEach(group.hunks) { hunk in
                                                Text(hunk.header)
                                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                                    .foregroundStyle(.secondary)
                                                    .padding(.vertical, 4)
                                                    .padding(.horizontal, 8)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .background(Color.secondary.opacity(0.12))

                                                ForEach(hunk.lines, id: \.self) { line in
                                                    Text(line)
                                                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                                                        .foregroundStyle(lineColor(line))
                                                        .frame(maxWidth: .infinity, alignment: .leading)
                                                        .background(lineBackgroundColor(line))
                                                        .padding(.horizontal, 8)
                                                }
                                            }
                                        }
                                        .background(Color.black.opacity(0.85))
                                    }
                                }
                                .cornerRadius(6)
                            }
                            .groupBoxStyle(ModernGroupBoxStyle())
                        }
                    }
                }
            }
        }
        .sourceControlEmbedded()
    }

    private func lineColor(_ line: String) -> Color {
        if line.hasPrefix("+") && !line.hasPrefix("+++") { return .green.opacity(0.9) }
        if line.hasPrefix("-") && !line.hasPrefix("---") { return .red.opacity(0.9) }
        return .white.opacity(0.85)
    }

    private func lineBackgroundColor(_ line: String) -> Color {
        if line.hasPrefix("+") && !line.hasPrefix("+++") { return .green.opacity(0.08) }
        if line.hasPrefix("-") && !line.hasPrefix("---") { return .red.opacity(0.08) }
        return .clear
    }
}
