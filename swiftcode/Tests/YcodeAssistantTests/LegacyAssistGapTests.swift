import Foundation
import Testing
@testable import YcodeAssistant

@Suite struct LegacyAssistGapTests {

    @Test func hermesConfigurationNormalisedToolsets() {
        #expect(HermesConfiguration(toolsets: "file,web").normalisedToolsets == "file,web")
        #expect(HermesConfiguration(toolsets: "  file,web  ").normalisedToolsets == "file,web")
        #expect(HermesConfiguration(toolsets: "   ").normalisedToolsets == nil)
        #expect(HermesConfiguration(toolsets: "").normalisedToolsets == nil)
        #expect(HermesConfiguration().normalisedToolsets == nil)
    }

    @Test func assistantSettingsProviderOpenCodeRoundTrips() throws {
        var settings = AssistantSettings()
        settings.provider = .openCode
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AssistantSettings.self, from: data)
        #expect(decoded.provider == .openCode)
        #expect(ProviderKind(rawValue: "openCode") == .openCode)
    }

    @Test @MainActor func sdkConfigForExplicitClaudeAndGPTNeverUsesGemini() async {
        let router = AssistModelRouter()
        let claude = await router.selectModelForSDK(
            preferredID: "anthropic/claude-sonnet-4-5",
            strategy: .providerDefault,
            candidates: [],
            useCloudModel: false,
            catalog: AntigravitySDKCatalog())
        #expect(claude.model.id == "anthropic/claude-sonnet-4-5")
        #expect(claude.config.provider != .antigravity)
        #expect(!claude.config.model.contains("gemini"))

        let gpt = await router.selectModelForSDK(
            preferredID: "gpt-4o",
            strategy: .providerDefault,
            candidates: [],
            useCloudModel: false,
            catalog: AntigravitySDKCatalog())
        #expect(gpt.model.id == "gpt-4o")
        #expect(gpt.config.provider != .antigravity)
        #expect(!gpt.config.model.contains("gemini"))
    }

    @Test @MainActor func failoverNeverSilentlyFallsBackToGemini() async throws {
        struct E: LocalizedError { let message: String; var errorDescription: String? { message } }
        let candidates = [
            AssistCandidateModel(id: "anthropic/claude-sonnet-4-5", displayName: "Claude Sonnet",
                                 provider: .ollama, priority: 5, source: .provider),
            AssistCandidateModel(id: "anthropic/claude-haiku-4-5", displayName: "Claude Haiku",
                                 provider: .ollama, priority: 5, source: .provider),
            AssistCandidateModel(id: "google/gemini-2.5-pro", displayName: "Gemini Pro",
                                 provider: .ollama, contextWindow: 1_000_000, priority: 10,
                                 source: .provider),
        ]
        let discovery = AssistModelDiscoveryService.shared
        let settings = AppSettings.shared
        let savedModels = discovery.discoveredModels
        let savedDate = discovery.lastDiscoveryDate
        let savedStrategy = settings.assistModelRoutingStrategy
        let savedSwitch = settings.assistAutomaticallySwitchModels
        let savedCloud = settings.useSwiftCodeCloudModel
        discovery.discoveredModels = candidates.map { AssistAvailableModel(candidate: $0) }
        discovery.lastDiscoveryDate = Date()
        settings.assistModelRoutingStrategy = "app_models"
        settings.assistAutomaticallySwitchModels = true
        settings.useSwiftCodeCloudModel = false
        defer {
            discovery.discoveredModels = savedModels
            discovery.lastDiscoveryDate = savedDate
            settings.assistModelRoutingStrategy = savedStrategy
            settings.assistAutomaticallySwitchModels = savedSwitch
            settings.useSwiftCodeCloudModel = savedCloud
        }
        let router = AssistModelRouter()
        let failed = candidates[0]
        let result = await router.handleTurnFailureWithKeyRotation(
            failedModel: failed, error: E(message: "boom"), completedTurnContent: "half the fix",
            executedToolsCount: 2, objective: "Fix the bug", automaticallySwitchModels: true,
            eligibleCandidates: candidates, keyRotation: nil, alternativeKeysEnabled: false,
            isGoogleOAuthAuthenticated: false)
        let next = try #require(result)
        #expect(next.nextModel.id == "anthropic/claude-haiku-4-5")
        #expect(!next.nextModel.id.contains("gemini"))
        let event = router.lastFailoverEvent
        #expect(event?.failedModelID == failed.modelIdentifier)
        #expect(event?.failedModelID.contains("claude") == true)
        #expect(event?.newModelID == "anthropic/claude-haiku-4-5")
        #expect(event?.newModelID.contains("gemini") == false)
        #expect(router.failoverHistory.count >= 1)
    }
}
