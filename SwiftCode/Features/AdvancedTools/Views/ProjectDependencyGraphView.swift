import SwiftUI

struct ProjectDependencyGraphView: View {
    @EnvironmentObject private var projectManager: ProjectManager

    private var dependencyRows: [(String, [String])] {
        guard let project = projectManager.activeProject else { return [] }
        let files = project.files.flatMapDeep(includeDirectories: false).filter { $0.name.hasSuffix(".swift") }
        return files.map { node in
            let url = project.directoryURL.appendingPathComponent(node.path)
            let imports = ((try? String(contentsOf: url)) ?? "")
                .split(separator: "\n")
                .compactMap { line -> String? in
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard trimmed.hasPrefix("import ") else { return nil }
                    return String(trimmed.dropFirst(7))
                }
            return (node.name, imports)
        }
    }

    var body: some View {
        AdvancedToolScreen(title: "Dependency Graph") {
            AdvancedToolCard(title: "Swift Import Graph", subtitle: "Dependencies parsed from import statements") {
                ForEach(dependencyRows, id: \.0) { file, imports in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(file).font(.headline)
                        Text(imports.isEmpty ? "No imports" : imports.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Divider()
                }
            }
        }
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
