import Foundation

public final class AssistGitManager: AssistGitManagerProtocol {
    private let project: Project?

    public init(project: Project?) {
        self.project = project
    }

    public func status() throws -> String {
        guard let project = project else { return "No project active" }
        return "Project: \(project.name) (iOS Sandbox Mode)"
    }

    public func commit(message: String) throws {
        // Internal project snapshotting replaces git commits in iOS sandbox
        try AssistSnapshotFunctions.createSnapshot(project: project?.directoryURL ?? URL(fileURLWithPath: "/"), message: message)
    }

    public func push() async throws {
        // iOS sandbox: Simulation or remote sync via GitHub API (not shell)
        // For now, it's replaced by snapshot system, but we'll leave as NO-OP for actual Git operations
    }

    public func add(path: String) throws {
        // NO-OP in iOS sandbox
    }
}
