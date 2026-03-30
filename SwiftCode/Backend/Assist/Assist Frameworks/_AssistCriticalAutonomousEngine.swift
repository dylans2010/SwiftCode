import Foundation

/// [CRITICAL SYSTEM FILE] - HIGH RISK
/// Controls the full autonomous execution loop for the Assist agent.
@MainActor
public final class _AssistCriticalAutonomousEngine {
    private let context: AssistContext
    private let orchestrator: _AssistCriticalTaskOrchestrator
    private let validator: _AssistCriticalValidationEngine
    private let analyzer: _AssistCriticalCodebaseAnalyzer

    private var isRunning = false
    private var iterationCount = 0
    private var previousValidationFeedbacks: [String] = []

    public init(context: AssistContext) {
        self.context = context
        self.orchestrator = _AssistCriticalTaskOrchestrator(context: context)
        self.validator = _AssistCriticalValidationEngine(context: context)
        self.analyzer = _AssistCriticalCodebaseAnalyzer(context: context)
    }

    /// Starts the autonomous execution loop for a given user intent.
    public func run(intent: String) async throws {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        context.logger.info("Starting autonomous engine for: \(intent)", toolId: "AutonomousEngine")

        // 0. Initial Analysis
        let summary = try analyzer.analyze()
        context.logger.info("Initial codebase analysis complete. Found \(summary.swiftFileCount) Swift files.", toolId: "AutonomousEngine")

        iterationCount = 0
        var currentIntent = intent
        var isSatisfied = false

        let takeoverEnabled = UserDefaults.standard.bool(forKey: "assist.takeoverEnabled")
        let maxIterations = takeoverEnabled ? Int.max : 5

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
                // Safety Detection
                if detectInfiniteLoop(feedback: validationResult.feedback) {
                    await triggerTakeover(reason: "Infinite loop detected: Validation feedback is repeating without progress.")
                    throw AutonomousError.infiniteLoopDetected
                }

                context.logger.warning("Validation failed: \(validationResult.feedback). Retrying...", toolId: "AutonomousEngine")
                previousValidationFeedbacks.append(validationResult.feedback)
                currentIntent = "The previous attempt failed. Feedback: \(validationResult.feedback). Original goal: \(intent)"
            }

            // Check for no-progress cycle
            if iterationCount > 10 && !isSatisfied {
                 await triggerTakeover(reason: "No-progress cycle detected after 10 iterations.")
                 throw AutonomousError.noProgressCycle
            }
        }

        if !isSatisfied {
            context.logger.error("Reached maximum iterations (\(maxIterations)) without full satisfaction.", toolId: "AutonomousEngine")
            await triggerTakeover(reason: "Reached maximum iterations (\(maxIterations)) without satisfying the goal.")
            throw AutonomousError.maxIterationsReached
        }
    }

    private func detectInfiniteLoop(feedback: String) -> Bool {
        // Simple heuristic: if the same feedback appears 3 times, it's likely an infinite loop
        let occurrences = previousValidationFeedbacks.filter { $0 == feedback }.count
        return occurrences >= 3
    }

    private func triggerTakeover(reason: String) async {
        await MainActor.run {
            AssistManager.shared.takeoverReason = reason
            // In a real system, this would show an overlay to the user
        }
    }

    public enum AutonomousError: Error {
        case maxIterationsReached
        case infiniteLoopDetected
        case noProgressCycle
    }
}
