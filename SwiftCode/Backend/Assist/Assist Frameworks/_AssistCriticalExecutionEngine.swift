import Foundation

/// [CRITICAL SYSTEM FILE] - HIGH RISK
/// The primary execution bridge for file and project operations. Ensures all changes are real and integrated.
public final class _AssistCriticalExecutionEngine {
    private let context: AssistContext
    private let baseEngine: AssistExecutionEngine

    public init(context: AssistContext) {
        self.context = context
        self.baseEngine = AssistExecutionEngine(context: context, registry: AssistToolRegistry())
    }

    /// Executes a plan and ensures all new files are visible to the project.
    @MainActor
    public func execute(plan: inout AssistExecutionPlan) async throws {
        context.logger.info("Executing via Critical Execution Engine", toolId: "CriticalExecution")

        try await baseEngine.execute(plan: &plan)

        // After execution, force a refresh of the project state to ensure UI and file system are in sync.
        if let project = ProjectManager.shared.activeProject {
            ProjectManager.shared.refreshFileTree(for: project)
        }
    }
}
