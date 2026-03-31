import Foundation

public final class AssistExecutionEngine {
    private let context: AssistContext
    private let registry: AssistToolRegistry

    public init(context: AssistContext, registry: AssistToolRegistry) {
        self.context = context
        self.registry = registry
    }

    @MainActor
    public func execute(plan: inout AssistExecutionPlan) async throws {
        context.logger.info("Executing plan: \(plan.goal)")
        plan.status = .running

        for i in 0..<plan.steps.count {
            var step = plan.steps[i]
            let stepTitle = "Step \(i+1)/\(plan.steps.count)"
            context.logger.info("\(stepTitle): \(step.description)", toolId: step.toolId)

            step.status = .running
            plan.steps[i] = step
            TasksAIPlanner.shared.updateStep(id: step.id, status: .running)

            do {
                // Unified tool execution logic (integrating what was previously in AssistLoop)
                guard let tool = registry.getTool(step.toolId) else {
                    throw AssistExecutionError.toolNotFound(step.toolId)
                }

                context.logger.info("Executing tool: \(tool.name)", toolId: step.toolId)

                // Map the input to [String: Any] as required by AssistTool protocol
                var toolInput = step.input as [String: Any]
                if let path = toolInput["path"] as? String,
                   ["code_refactor", "file_read", "file_append"].contains(step.toolId),
                   !context.fileSystem.exists(at: path),
                   let createFileTool = registry.getTool("file_create") {
                    _ = try await createFileTool.execute(input: ["path": path, "content": "", "overwrite": false], context: context)
                    context.logger.info("Auto-created missing file at \(path) before executing \(step.toolId)", toolId: "file_create")
                }

                let result = try await tool.execute(input: toolInput, context: context)

                step.result = result
                step.status = result.success ? .completed : .failed
                plan.steps[i] = step
                TasksAIPlanner.shared.updateStep(id: step.id, status: step.status, result: result)

                if !result.success {
                    context.logger.error("Step failed: \(result.error ?? "Unknown error")", toolId: step.toolId)
                    if context.safetyLevel == .conservative {
                        plan.status = .failed
                        return
                    }
                } else {
                    // Force project refresh on successful file writes or modifications
                    if ["file_write", "code_refactor", "file_create", "file_append"].contains(step.toolId) {
                        if let project = ProjectManager.shared.activeProject {
                            ProjectManager.shared.refreshFileTree(for: project)
                        }
                    }
                }
            } catch {
                context.logger.error("Step execution error: \(error.localizedDescription)", toolId: step.toolId)
                step.status = .failed
                plan.status = .failed
                plan.steps[i] = step
                throw error
            }
        }

        plan.status = .completed
        if TasksAIPlanner.shared.currentPlan?.id == plan.id {
            TasksAIPlanner.shared.currentPlan?.status = .completed
        }
        context.logger.info("Plan execution completed: \(plan.goal)")
    }
}

public enum AssistExecutionError: LocalizedError {
    case toolNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .toolNotFound(let id): return "Tool not found: \(id)"
        }
    }
}
