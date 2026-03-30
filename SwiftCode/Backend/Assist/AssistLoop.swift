import Foundation

public final class AssistLoop {
    private let plan: AssistPlan

    public init(plan: AssistPlan) {
        self.plan = plan
    }

    public func execute() async throws {
        for step in plan.steps {
            try await executeStep(step)
        }
    }

    private func executeStep(_ step: AssistStep) async throws {
        for action in step.actions {
            try await executeAction(action)
        }
    }

    @MainActor
    private func executeAction(_ action: AssistAction) async throws {
        switch action {
        case .createFile(let path, let content):
            let url = URL(fileURLWithPath: path)
            let parentDir = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
            try content.write(to: url, atomically: true, encoding: .utf8)

        case .modifyFile(let path, let patchContent):
            let url = URL(fileURLWithPath: path)
            let original = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            // Simple patch application: if patch starts with //, treat as append
            if patchContent.hasPrefix("//") {
                let modified = original + "\n" + patchContent
                try modified.write(to: url, atomically: true, encoding: .utf8)
            } else {
                // In a real system, we'd use a robust diff engine.
                // For now, overwrite if it's a full replacement.
                try patchContent.write(to: url, atomically: true, encoding: .utf8)
            }

        case .deleteFile(let path):
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: path) {
                try FileManager.default.removeItem(at: url)
            }

        case .renameFile(let oldPath, let newPath):
            let oldURL = URL(fileURLWithPath: oldPath)
            let newURL = URL(fileURLWithPath: newPath)
            try FileManager.default.moveItem(at: oldURL, to: newURL)

        case .runTest(_):
            // Execute real tests if a project is active
            if let project = ProjectManager.shared.currentProject {
                await TestToolsManager.shared.runTests(forProject: project)
            }
        }
    }
}
