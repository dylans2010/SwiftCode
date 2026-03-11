import Foundation

public struct Project: Identifiable, Codable {
    public var id: UUID
    public var name: String
    public var createdAt: Date
    public var lastOpened: Date
    public var files: [FileNode]
    public var githubRepo: String?
    public var githubToken: String? // stored in keychain, not persisted here
    public var description: String

    public init(name: String) {
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
    public var directoryURL: URL {
        ProjectManager.shared.projectsDirectory.appendingPathComponent(name)
    }

    public var fileCount: Int {
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
