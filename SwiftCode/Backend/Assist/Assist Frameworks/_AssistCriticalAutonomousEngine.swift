import Foundation

/// [CRITICAL SYSTEM FILE] - HIGH RISK
/// Controls the full autonomous execution loop for the Assist agent.
@MainActor
public final class _AssistCriticalAutonomousEngine {
    private let context: AssistContext
    private let orchestrator: _AssistCriticalTaskOrchestrator
    private let validator: _AssistCriticalValidationEngine

    private var isRunning = false
    private var iterationCount = 0
    private let maxIterations = 5

    public init(context: AssistContext) {
        self.context = context
        self.orchestrator = _AssistCriticalTaskOrchestrator(context: context)
        self.validator = _AssistCriticalValidationEngine(context: context)
    }

    /// Starts the autonomous execution loop for a given user intent.
    public func run(intent: String) async throws {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        context.logger.info("Starting autonomous engine for: \(intent)", toolId: "AutonomousEngine")

        iterationCount = 0
        var currentIntent = intent
        var isSatisfied = false

        while !isSatisfied && iterationCount < maxIterations {
            iterationCount += 1
            context.logger.info("Starting iteration \(iterationCount)", toolId: "AutonomousEngine")

            // 1. Plan & Orchestrate
            var plan = try await orchestrator.createPlan(for: currentIntent)

            // 2. Execute
            try await orchestrator.execute(plan: &plan)

            // 3. Validate
            let validationResult = try await validator.validate(plan: plan)

            if validationResult.isSuccess {
                isSatisfied = true
                context.logger.info("Task satisfied after \(iterationCount) iterations.", toolId: "AutonomousEngine")
            } else {
                context.logger.warning("Validation failed: \(validationResult.feedback). Retrying...", toolId: "AutonomousEngine")
                currentIntent = "The previous attempt failed. Feedback: \(validationResult.feedback). Original goal: \(intent)"
            }
        }

        if !isSatisfied {
            context.logger.error("Reached maximum iterations (\(maxIterations)) without full satisfaction.", toolId: "AutonomousEngine")
            await MainActor.run {
                AssistManager.shared.takeoverReason = "Reached maximum iterations (\(maxIterations)) without satisfying the goal. Please review the codebase and provide manual guidance."
            }
            throw AutonomousError.maxIterationsReached
        }
    }

    public enum AutonomousError: Error {
        case maxIterationsReached
    }
}
