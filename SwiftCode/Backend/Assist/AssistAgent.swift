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
            // Check if Takeover Mode is enabled via settings
            let takeoverEnabled = UserDefaults.standard.bool(forKey: "assist.takeoverEnabled")

            if takeoverEnabled {
                // Use the Critical Autonomous Engine for deep execution loops
                let autonomousEngine = _AssistCriticalAutonomousEngine(context: context)
                try await autonomousEngine.run(intent: intent)

                // If it returns without error, it's satisfied.
                // We fetch the final report.
                return await generateFinalReport(for: intent)
            } else {
                // Standard semi-autonomous execution with Planner and Engine
                var plan = try await TasksAIPlanner.shared.generatePlan(intent: intent, context: context)

                guard !plan.steps.isEmpty else {
                    return AssistAIResponse(content: "", success: false, error: "No executable steps generated for this task.")
                }

                try await engine.execute(plan: &plan)

                if plan.status == .completed {
                    return await generateFinalReport(for: intent, plan: plan)
                }

                context.logger.error("Agent finished with incomplete status: \(plan.status.rawValue)")
                return AssistAIResponse(content: "Task ended with status: \(plan.status.rawValue)", success: false, error: "Execution did not complete.")
            }
        } catch {
            context.logger.error("Agent execution failed: \(error.localizedDescription)")
            return AssistAIResponse(content: "I couldn't complete that request safely.", success: false, error: "Assist execution failed.")
        }
    }

    private func generateFinalReport(for intent: String, plan: AssistExecutionPlan? = nil) async -> AssistAIResponse {
        context.logger.info("Generating final report for: \(intent)")

        let providerRawValue = UserDefaults.standard.string(forKey: "assist.selectedProvider") ?? AssistModelProvider.openAI.rawValue
        let provider = AssistModelProvider(rawValue: providerRawValue) ?? .openAI
        let apiKey = APIKeyManager.shared.retrieveKey(service: provider.apiKeyProvider)

        var prompt = "\(AssistAgenticPrompt.systemPrompt)\n\n# TASK COMPLETED\nTask: \(intent)\nStatus: Completed.\n"

        if let plan = plan {
            prompt += "\n## EXECUTION DATA\n"
            prompt += plan.steps.map { "- \($0.description) (\($0.status.rawValue))" }.joined(separator: "\n")
        }

        prompt += "\n\nProvide the final report in the strict markdown format specified in the system prompt."

        let finalResponse = await AssistLLMService.generateResponse(
            prompt: prompt,
            provider: provider,
            apiKey: apiKey
        )

        return finalResponse
    }
}
