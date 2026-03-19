import UIKit
import Foundation

@MainActor
final class CollaborationSessionStore: ObservableObject {
    static let shared = CollaborationSessionStore()

    private var managers: [UUID: CollaborationManager] = [:]
    private init() {}

    func manager(for project: Project, creatorID: String = UIDevice.current.name) -> CollaborationManager {
        if let existing = managers[project.id] {
            return existing
        }
        let manager = CollaborationManager(projectID: project.id, creatorID: creatorID, projectName: project.name)
        managers[project.id] = manager
        return manager
    }
}
