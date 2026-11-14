import SwiftUI
import YcodeIDECore

struct DiffViewerView: View {
    @Environment(ProjectSessionStore.self) private var sessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var originalContent = ""
    @State private var modifiedContent = ""
    @State private var fileEntries: [FileDiffItem] = []
    @State private var collapsedFiles: Set<String> = []

    struct DiffLine: Identifiable {
        let id = UUID()
        let lineNumber: Int
        let text: String
        let type: DiffType

        enum DiffType {
            case unchanged
            case added
            case removed
        }
    }

    struct FileDiffItem: Identifiable {
        let id: String
        let filePath: String
        let lines: [DiffLine]

        var addedCount: Int {
            lines.filter { $0.type == .added }.count
        }

        var removedCount: Int {
            lines.filter { $0.type == .removed }.count
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if fileEntries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary.opacity(0.5))
                        Text("No Changes To Display")
                            .foregroundStyle(.secondary)
                        Text("Edits to the current file will appear here.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(24)
                    .liquidGlass(style: .standard, cornerRadius: 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(fileEntries) { entry in
                                VStack(alignment: .leading, spacing: 0) {
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            if collapsedFiles.contains(entry.filePath) {
                                                collapsedFiles.remove(entry.filePath)
                                            } else {
                                                collapsedFiles.insert(entry.filePath)
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: collapsedFiles.contains(entry.filePath) ? "chevron.right" : "chevron.down")
                                                .font(.caption2.bold())
                                                .foregroundStyle(.secondary)
                                                .frame(width: 14)

                                            Image(systemName: "doc.text")
                                                .foregroundStyle(Color.accentColor)

                                            Text(entry.filePath)
                                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                                .foregroundStyle(.primary)
                                                .lineLimit(1)

                                            Spacer()

                                            if entry.addedCount > 0 {
                                                Text("+\(entry.addedCount)")
                                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                    .foregroundStyle(.secondary)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.secondary.opacity(0.12))
                                                    .cornerRadius(4)
                                            }

                                            if entry.removedCount > 0 {
                                                Text("-\(entry.removedCount)")
                                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                    .foregroundStyle(.secondary)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.secondary.opacity(0.12))
                                                    .cornerRadius(4)
                                            }
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(Color.secondary.opacity(0.06))
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    if !collapsedFiles.contains(entry.filePath) {
                                        Divider()

                                        VStack(alignment: .leading, spacing: 0) {
                                            ForEach(entry.lines) { line in
                                                HStack(spacing: 4) {
                                                    Text("\(line.lineNumber)")
                                                        .font(.caption2.monospaced())
                                                        .foregroundStyle(.secondary)
                                                        .frame(width: 36, alignment: .trailing)

                                                    Text(prefixForType(line.type))
                                                        .font(.caption.monospaced())
                                                        .foregroundStyle(colorForType(line.type))
                                                        .frame(width: 14)

                                                    Text(line.text)
                                                        .font(.caption.monospaced())
                                                        .foregroundStyle(.primary)
                                                        .lineLimit(1)

                                                    Spacer()
                                                }
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 2)
                                                .background(backgroundForType(line.type))
                                            }
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                                .background(Color.secondary.opacity(0.03))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                                )
                            }
                        }
                        .padding(12)
                    }
                }
            }
            .navigationTitle("Diff Viewer")
            .toolbar {
                if !fileEntries.isEmpty {
                    ToolbarItem(placement: .automatic) {
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
                                    collapsedFiles = Set(fileEntries.map(\.filePath))
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { computeDiff() }
        }
    }

    private func prefixForType(_ type: DiffLine.DiffType) -> String {
        switch type {
        case .unchanged: return " "
        case .added: return "+"
        case .removed: return "-"
        }
    }

    private func colorForType(_ type: DiffLine.DiffType) -> Color {
        switch type {
        case .unchanged: return .secondary
        case .added: return .green.opacity(0.9)
        case .removed: return .red.opacity(0.9)
        }
    }

    private func backgroundForType(_ type: DiffLine.DiffType) -> Color {
        switch type {
        case .unchanged: return .clear
        case .added: return .green.opacity(0.08)
        case .removed: return .red.opacity(0.08)
        }
    }

    private func computeDiff() {
        var lines: [DiffLine] = []
        var path = "Active File"

        if let activeDiff = sessionStore.activeFileDiff {
            path = activeDiff.filePath
            originalContent = activeDiff.beforeContent
            modifiedContent = activeDiff.afterContent

            let origLines = originalContent.components(separatedBy: "\n")
            let modLines = modifiedContent.components(separatedBy: "\n")

            let maxLines = max(origLines.count, modLines.count)
            for i in 0..<maxLines {
                let origLine = i < origLines.count ? origLines[i] : nil
                let modLine = i < modLines.count ? modLines[i] : nil

                if origLine == modLine {
                    lines.append(DiffLine(lineNumber: i + 1, text: origLine ?? "", type: .unchanged))
                } else {
                    if let orig = origLine {
                        lines.append(DiffLine(lineNumber: i + 1, text: orig, type: .removed))
                    }
                    if let mod = modLine {
                        lines.append(DiffLine(lineNumber: i + 1, text: mod, type: .added))
                    }
                }
            }

            fileEntries = [FileDiffItem(id: path, filePath: path, lines: lines)]
            return
        }

        guard let project = sessionStore.activeProject,
              let node = sessionStore.activeFileNode else {
            fileEntries = []
            return
        }

        path = node.path
        let fileURL = project.directoryURL.appendingPathComponent(node.path)
        let diskContent = (try? String(contentsOf: fileURL.standardizedFileURL, encoding: .utf8)) ?? ""
        let editorContent = sessionStore.activeFileContent

        originalContent = diskContent
        modifiedContent = editorContent

        let origLines = diskContent.components(separatedBy: "\n")
        let modLines = editorContent.components(separatedBy: "\n")

        let maxLines = max(origLines.count, modLines.count)
        for i in 0..<maxLines {
            let origLine = i < origLines.count ? origLines[i] : nil
            let modLine = i < modLines.count ? modLines[i] : nil

            if origLine == modLine {
                lines.append(DiffLine(lineNumber: i + 1, text: origLine ?? "", type: .unchanged))
            } else {
                if let orig = origLine {
                    lines.append(DiffLine(lineNumber: i + 1, text: orig, type: .removed))
                }
                if let mod = modLine {
                    lines.append(DiffLine(lineNumber: i + 1, text: mod, type: .added))
                }
            }
        }

        fileEntries = [FileDiffItem(id: path, filePath: path, lines: lines)]
    }
}
