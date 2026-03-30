import Foundation

public final class AssistExecutionEngine {
    private let context: AssistContext
    private let registry: AssistToolRegistry

    public init(context: AssistContext, registry: AssistToolRegistry) {
        self.context = context
        self.registry = registry
    }

    public func execute(plan: inout AssistExecutionPlan) async throws {
        context.logger.info("Executing plan: \(plan.goal)")
        plan.status = .running

        for i in 0..<plan.steps.count {
            var step = plan.steps[i]
            let stepTitle = "Step \(i+1)/\(plan.steps.count)"
            context.logger.info("\(stepTitle): \(step.description)", toolId: step.toolId)

            await MainActor.run {
                step.status = .running
                plan.steps[i] = step
                TasksAIPlanner.shared.updateStep(id: step.id, status: .running)
            }

            do {
                // Unified tool execution logic (integrating what was previously in AssistLoop)
                guard let tool = registry.getTool(step.toolId) else {
                    throw AssistExecutionError.toolNotFound(step.toolId)
                }

                context.logger.info("Executing tool: \(tool.name)", toolId: step.toolId)

                // Map the input to [String: Any] as required by AssistTool protocol
                let toolInput = step.input as [String: Any]

                let result = try await tool.execute(input: toolInput, context: context)

                await MainActor.run {
                    step.result = result
                    step.status = result.success ? .completed : .failed
                    plan.steps[i] = step
                    TasksAIPlanner.shared.updateStep(id: step.id, status: step.status, result: result)
                }

                if !result.success {
                    context.logger.error("Step failed: \(result.error ?? "Unknown error")", toolId: step.toolId)
                    if context.safetyLevel == .conservative {
                        await MainActor.run { plan.status = .failed }
                        return
                    }
                } else {
                    // Force project refresh on successful file writes or modifications
                    if step.toolId == "file_write" || step.toolId == "code_refactor" || step.toolId == "file_create" {
                        await MainActor.run {
                            if let project = ProjectManager.shared.activeProject {
                                ProjectManager.shared.refreshFileTree(for: project)
                            }
                        }
                    }
                }
            } catch {
                context.logger.error("Step execution error: \(error.localizedDescription)", toolId: step.toolId)
                await MainActor.run {
                    step.status = .failed
                    plan.status = .failed
                    plan.steps[i] = step
                }
                throw error
            }
        }

        await MainActor.run {
            plan.status = .completed
            if TasksAIPlanner.shared.currentPlan?.id == plan.id {
                TasksAIPlanner.shared.currentPlan?.status = .completed
            }
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
