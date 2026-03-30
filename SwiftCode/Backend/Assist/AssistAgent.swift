import Foundation

@MainActor
public final class AssistAgent: ObservableObject {
    private let context: AssistContext
    private let planner: AssistPlanner
    private let engine: AssistExecutionEngine
    private let registry: AssistToolRegistry

    @Published public var isRunning = false

    public init(context: AssistContext, registry: AssistToolRegistry) {
        self.context = context
        self.registry = registry
        self.planner = AssistPlanner(context: context)
        self.engine = AssistExecutionEngine(context: context, registry: registry)
    }

    public func processIntent(_ intent: String) async throws {
        isRunning = true
        defer { isRunning = false }

        // 1. Plan
        var plan = try await planner.plan(for: intent)

        // 2. Execute
        try await engine.execute(plan: &plan)

        // 3. Finalize
        if plan.status == .completed {
            context.logger.info("Agent successfully completed task: \(intent)")
        } else {
            context.logger.error("Agent failed to complete task: \(intent)")
        }
    }
}
