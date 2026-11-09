import Foundation
import YcodeAssistant

public final class ProjectMetadataManager: Sendable {
    public static let shared = ProjectMetadataManager()
    private init() {}

    @MainActor
    public func generateMetadata(for project: Project) -> ProjectMetadata {
        return ProjectMetadata(
            name: project.name,
            description: project.description,
            author: AppSettings.shared.fileHeaderAuthor,
            version: RecentProjects.projectVersionInfo(at: project.directoryURL).marketing ?? "1.0.0",
            createdAt: project.createdAt,
            updatedAt: Date()
        )
    }
}
