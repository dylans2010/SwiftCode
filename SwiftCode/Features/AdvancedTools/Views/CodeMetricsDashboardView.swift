import SwiftUI

struct CodeMetricsDashboardView: View {
    @EnvironmentObject private var projectManager: ProjectManager

    private var files: [FileNode] {
        projectManager.activeProject?.files.flatMapDeep(includeDirectories: false) ?? []
    }

    private var swiftFiles: [FileNode] { files.filter { $0.name.hasSuffix(".swift") } }

    private var totalLOC: Int {
        guard let project = projectManager.activeProject else { return 0 }
        return files.reduce(0) { result, node in
            let url = project.directoryURL.appendingPathComponent(node.path)
            let text = (try? String(contentsOf: url)) ?? ""
            return result + text.split(separator: "\n", omittingEmptySubsequences: false).count
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                metric("Total Files", value: "\(files.count)")
                metric("Total Lines of Code", value: "\(totalLOC)")
                metric("Language Breakdown", value: languageBreakdown())
                metric("Most Modified Files", value: projectManager.modifiedFilePaths.prefix(3).joined(separator: ", "))
                metric("Complexity Indicator", value: complexityLabel())
                Spacer()
            }
            .padding()
            .navigationTitle("Code Metrics")
        }
    }

    private func languageBreakdown() -> String {
        let groups = Dictionary(grouping: files, by: { $0.fileExtension.isEmpty ? "other" : $0.fileExtension })
        return groups.sorted(by: { $0.value.count > $1.value.count }).prefix(4).map { "\($0.key): \($0.value.count)" }.joined(separator: ", ")
    }

    private func complexityLabel() -> String {
        if totalLOC > 10_000 || swiftFiles.count > 120 { return "High" }
        if totalLOC > 3_000 || swiftFiles.count > 40 { return "Moderate" }
        return "Low"
    }

    private func metric(_ title: String, value: String) -> some View {
        GroupBox(title) { Text(value.isEmpty ? "n/a" : value) }
    }
}

private extension Array where Element == FileNode {
    func flatMapDeep(includeDirectories: Bool) -> [FileNode] {
        flatMap { node in
            if node.isDirectory {
                return (includeDirectories ? [node] : []) + node.children.flatMapDeep(includeDirectories: includeDirectories)
            }
            return [node]
        }
    }
}
