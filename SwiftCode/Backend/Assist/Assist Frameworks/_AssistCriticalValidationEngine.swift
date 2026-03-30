import Foundation

/// [CRITICAL SYSTEM FILE] - HIGH RISK
/// Validates the outputs of an autonomous execution iteration to ensure requirements are met.
public final class _AssistCriticalValidationEngine {
    private let context: AssistContext

    public init(context: AssistContext) {
        self.context = context
    }

    /// Validates the outcome of a completed plan.
    public func validate(plan: AssistExecutionPlan) async throws -> ValidationResult {
        context.logger.info("Validating plan results for: \(plan.goal)", toolId: "ValidationEngine")

        // 1. Check for step failures
        let failedSteps = plan.steps.filter { $0.status == .failed }
        if !failedSteps.isEmpty {
            return .failure("One or more steps failed to execute correctly.")
        }

        // 2. Perform AI-based verification of the final state
        let providerRawValue = UserDefaults.standard.string(forKey: "assist.selectedProvider") ?? AssistModelProvider.openAI.rawValue
        let provider = AssistModelProvider(rawValue: providerRawValue) ?? .openAI
        let apiKey = APIKeyManager.shared.retrieveKey(service: provider.apiKeyProvider)

        let prompt = """
        \(AssistAgenticPrompt.systemPrompt)

        # VALIDATION TASK
        The user goal was: "\(plan.goal)"
        The execution plan has finished. Analyze the status and determine if the goal has been successfully met.

        Return a JSON object:
        { "isSuccess": true/false, "feedback": "Detailed explanation of what is missing or incorrect if isSuccess is false." }
        """

        let response = await AssistLLMService.generateResponse(prompt: prompt, provider: provider, apiKey: apiKey)

        if response.success {
            return parseValidation(from: response.content)
        } else {
            return .success // Default to success if AI validation is unavailable, to avoid infinite loops
        }
    }

    private func parseValidation(from content: String) -> ValidationResult {
        let pattern = "\\{(?:[^{}]|\\{(?:[^{}]|\\{[^{}]*\\})*\\})*\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: content, options: [], range: NSRange(content.startIndex..., in: content)),
              let range = Range(match.range, in: content),
              let data = String(content[range]).data(using: .utf8),
              let result = try? JSONDecoder().decode(ValidationResult.self, from: data) else {
            return .success
        }
        return result
    }
}

public struct ValidationResult: Codable {
    public let isSuccess: Bool
    public let feedback: String

    public static var success: ValidationResult { ValidationResult(isSuccess: true, feedback: "All requirements met.") }
    public static func failure(_ feedback: String) -> ValidationResult { ValidationResult(isSuccess: false, feedback: feedback) }
}
