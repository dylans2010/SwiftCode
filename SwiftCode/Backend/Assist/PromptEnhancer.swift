import Foundation

public final class PromptEnhancer {
    public static func enhancePrompt(userInput: String) async -> String {
        let systemPrompt = """
        You are an expert software architect. Rewrite vague user prompts into highly detailed, technically specific instructions for an autonomous coding agent.

        Rules:
        - Expand vague ideas into concrete steps
        - Specify frameworks and architecture
        - Infer missing details
        - Do not explain anything
        - Output must be directly executable
        """

        let providerRawValue = UserDefaults.standard.string(forKey: "assist.selectedProvider") ?? AssistModelProvider.openAI.rawValue
        let provider = AssistModelProvider(rawValue: providerRawValue) ?? .openAI
        let apiKey = APIKeyManager.shared.retrieveKey(service: provider.apiKeyProvider)
        let selectedModelID = AssistModelManager.shared.selectedModelID

        let response = await AssistLLMService.generateResponse(
            prompt: "\(systemPrompt)\n\nUser Input: \(userInput)",
            provider: provider,
            apiKey: apiKey,
            modelOverride: selectedModelID
        )

        if response.success {
            return response.content
        } else {
            return userInput
        }
    }
}
