import SwiftUI

struct ErrorsPanelView: View {
    @EnvironmentObject private var projectManager: ProjectManager
    @Environment(\.dismiss) private var dismiss

    @State private var errors: [CodeError] = []
    @State private var filterSeverity: CodeError.Severity?

    var filteredErrors: [CodeError] {
        if let severity = filterSeverity {
            return errors.filter { $0.severity == severity }
        }
        return errors
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Severity filter
                HStack(spacing: 8) {
                    filterButton(nil, label: "All", count: errors.count)
                    filterButton(.error, label: "Errors", count: errors.filter { $0.severity == .error }.count)
                    filterButton(.warning, label: "Warnings", count: errors.filter { $0.severity == .warning }.count)
                    filterButton(.info, label: "Info", count: errors.filter { $0.severity == .info }.count)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider().opacity(0.3)

                if filteredErrors.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.green.opacity(0.6))
                        Text("No Issues Found")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredErrors) { error in
                        Button {
                            navigateToError(error)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: error.severity.icon)
                                    .foregroundStyle(colorForSeverity(error.severity))

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(error.fileName)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(.orange)
                                        Text(":\(error.lineNumber)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(error.message)
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.8))
                                        .lineLimit(2)
                                    Text(error.source.rawValue)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color(red: 0.10, green: 0.10, blue: 0.14))
            .navigationTitle("Errors & Warnings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        analyzeProject()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear { analyzeProject() }
        }
    }

    private func filterButton(_ severity: CodeError.Severity?, label: String, count: Int) -> some View {
        Button {
            filterSeverity = severity
        } label: {
            Text("\(label) (\(count))")
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    filterSeverity == severity
                        ? Color.orange.opacity(0.3)
                        : Color.white.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 6)
                )
                .foregroundStyle(filterSeverity == severity ? .orange : .secondary)
        }
        .buttonStyle(.plain)
    }

    private func colorForSeverity(_ severity: CodeError.Severity) -> Color {
        switch severity {
        case .error: return .red
        case .warning: return .yellow
        case .info: return .blue
        }
    }

    private func analyzeProject() {
        guard let project = projectManager.activeProject else { return }
        var found: [CodeError] = []

        // Simple syntax analysis on all Swift files
        analyzeDirectory(project.directoryURL, relativeTo: project.directoryURL, errors: &found)
        errors = found
    }

    private func analyzeDirectory(_ url: URL, relativeTo base: URL, errors: inout [CodeError]) {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        while let fileURL = enumerator.nextObject() as? URL {
            guard fileURL.pathExtension == "swift" else { continue }
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
            let relativePath = fileURL.path.replacingOccurrences(of: base.path + "/", with: "")
            let fileName = fileURL.lastPathComponent
            let lines = content.components(separatedBy: "\n")

            // Simple brace matching
            var braceCount = 0
            for (i, line) in lines.enumerated() {
                braceCount += line.filter { $0 == "{" }.count
                braceCount -= line.filter { $0 == "}" }.count
                if braceCount < 0 {
                    errors.append(CodeError(
                        fileName: fileName,
                        filePath: relativePath,
                        lineNumber: i + 1,
                        message: "Unexpected Closing Brace",
                        severity: .error,
                        source: .syntaxAnalysis
                    ))
                    braceCount = 0
                }
            }
            if braceCount > 0 {
                errors.append(CodeError(
                    fileName: fileName,
                    filePath: relativePath,
                    lineNumber: lines.count,
                    message: "Expected \(braceCount) Closing Brace(s)",
                    severity: .error,
                    source: .syntaxAnalysis
                ))
            }
        }
    }

    private func navigateToError(_ error: CodeError) {
        let node = FileNode(name: error.fileName, path: error.filePath, isDirectory: false)
        projectManager.openFile(node)
        dismiss()
    }
}
