import Foundation

@MainActor
public final class AssistAgent: ObservableObject {
    private let context: AssistContext
    private let planner: AssistPlanner
    private let engine: AssistExecutionEngine

    @Published public var isRunning = false

    public init(context: AssistContext, registry: AssistToolRegistry) {
        self.context = context
        self.planner = AssistPlanner(context: context)
        self.engine = AssistExecutionEngine(context: context, registry: registry)
    }

    public func processIntent(_ intent: String) async -> AssistAIResponse {
        isRunning = true
        defer { isRunning = false }

        do {
            var plan = try await planner.plan(for: intent)
            try await engine.execute(plan: &plan)

            if plan.status == .completed {
                context.logger.info("Agent successfully completed task: \(intent)")
                return AssistAIResponse(content: "Task completed successfully.", success: true)
            }

            context.logger.error("Agent finished with incomplete status: \(plan.status.rawValue)")
            return AssistAIResponse(content: "Task ended with status: \(plan.status.rawValue)", success: false, error: "Execution did not complete.")
        } catch {
            context.logger.error("Agent execution failed: \(error.localizedDescription)")
            return AssistAIResponse(content: "I couldn't complete that request safely.", success: false, error: "Assist execution failed.")
        }
    }
}
