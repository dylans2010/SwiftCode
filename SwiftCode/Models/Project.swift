import Foundation

struct Project: Identifiable, Codable {
    var id: UUID
    var name: String
    var createdAt: Date
    var lastOpened: Date
    var files: [FileNode]
    var githubRepo: String?
    var githubToken: String? // stored in keychain, not persisted here
    var description: String

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.lastOpened = Date()
        self.files = []
        self.githubRepo = nil
        self.githubToken = nil
        self.description = ""
    }

    @MainActor
    var directoryURL: URL {
        ProjectManager.shared.projectsDirectory.appendingPathComponent(name)
    }

    var fileCount: Int {
        countFiles(in: files)
    }

    private func countFiles(in nodes: [FileNode]) -> Int {
        nodes.reduce(0) { count, node in
            if node.isDirectory {
                return count + countFiles(in: node.children)
            } else {
                return count + 1
            }
        }
    }
}
