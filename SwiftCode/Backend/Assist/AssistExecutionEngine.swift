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
            context.logger.info("Step \(i+1): \(step.description)", toolId: step.toolId)
            step.status = .running
            plan.steps[i] = step

            do {
                guard let tool = registry.getTool(step.toolId) else {
                    throw AssistExecutionError.toolNotFound(step.toolId)
                }

                let result = try await tool.execute(input: step.input, context: context)
                step.result = result
                step.status = result.success ? .completed : .failed

                if !result.success {
                    context.logger.error("Step failed: \(result.error ?? "Unknown error")", toolId: step.toolId)
                    if context.safetyLevel == .conservative {
                        plan.status = .failed
                        plan.steps[i] = step
                        return
                    }
                }
            } catch {
                context.logger.error("Step execution error: \(error.localizedDescription)", toolId: step.toolId)
                step.status = .failed
                plan.status = .failed
                plan.steps[i] = step
                throw error
            }

            plan.steps[i] = step
        }

        plan.status = .completed
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
