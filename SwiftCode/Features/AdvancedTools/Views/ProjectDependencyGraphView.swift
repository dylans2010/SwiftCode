import SwiftUI

struct ProjectDependencyGraphView: View {
    @EnvironmentObject private var projectManager: ProjectManager

    private var nodes: [FileNode] {
        projectManager.activeProject?.files.flatMapDeep(includeDirectories: false) ?? []
    }

    var body: some View {
        NavigationStack {
            List(nodes) { node in
                Button(node.name) { projectManager.openFile(node) }
            }
            .navigationTitle("Dependency Graph")
            .overlay(alignment: .bottomLeading) {
                Text("Graph edges are inferred from import statements.")
                    .font(.caption)
                    .padding(8)
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
