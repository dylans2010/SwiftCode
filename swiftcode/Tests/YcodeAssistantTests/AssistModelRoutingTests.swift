import Foundation
import Testing
@testable import YcodeAssistant

@Suite struct AssistModelRoutingTests {
    static func candidates() -> [AssistCandidateModel] {
        [
            AssistCandidateModel(id: "anthropic/claude-sonnet-4-5", displayName: "Claude Sonnet", provider: .openRouter, priority: 5, source: .provider),
            AssistCandidateModel(id: "gpt-4o", displayName: "GPT-4o", provider: .openAI, contextWindow: 128_000, priority: 10, source: .provider),
            AssistCandidateModel(id: "my-fine-tune", displayName: "My fine-tune", provider: .openRouter, priority: 1, source: .custom),
            AssistCandidateModel(id: "unconfigured/model", displayName: "Unconfigured", provider: .openRouter, isConfigured: false, source: .provider),
            AssistCandidateModel(id: "chat-only/model", displayName: "Chat only", provider: .openRouter, supportsToolCalling: false, supportsAgenticUse: false, source: .provider),
        ]
    }

    static func openRouterCandidates() -> [AssistCandidateModel] {
        [
            AssistCandidateModel(id: "anthropic/claude-sonnet-4-5", displayName: "Claude Sonnet", provider: .openRouter, priority: 5, source: .provider),
            AssistCandidateModel(id: "anthropic/claude-haiku-4-5", displayName: "Claude Haiku", provider: .openRouter, priority: 5, source: .provider),
            AssistCandidateModel(id: "google/gemini-2.5-pro", displayName: "Gemini Pro", provider: .openRouter, contextWindow: 1_000_000, priority: 10, source: .provider),
        ]
    }

    @Test func specificationPrefixesWin() {
        #expect(AssistModelSpecification.specification(for: "opencode:anthropic/claude-sonnet-4-5").provider == .openCode)
        #expect(AssistModelSpecification.specification(for: "hermes:openrouter:meta-llama/llama-4").provider == .hermes)
        #expect(AssistModelSpecification.specification(for: "swiftcode-cloud:qwen3").provider == .scCloud)
        #expect(AssistModelSpecification.specification(for: "swiftcode-cloud").provider == .scCloud)
    }

    @Test func specificationBranches() {
        let claude = AssistModelSpecification.specification(for: "claude-sonnet-4-5")
        #expect(claude.provider == .openRouter && claude.contextWindowTokens == 200_000)
        #expect(claude.displayName == "Claude 3.5 Sonnet")
        #expect(AssistModelSpecification.specification(for: "claude-3-7-sonnet").displayName == "Claude 3.7 Sonnet")
        #expect(AssistModelSpecification.specification(for: "claude-3-haiku").displayName == "Claude 3.5 Haiku")

        let gpt = AssistModelSpecification.specification(for: "gpt-4o")
        #expect(gpt.provider == .openAI && gpt.displayName == "GPT-4o" && gpt.contextWindowTokens == 128_000)
        #expect(gpt.capabilities.contains(.parallelToolCalls))
        #expect(AssistModelSpecification.specification(for: "gpt-4o-mini").displayName == "GPT-4o Mini")
        #expect(AssistModelSpecification.specification(for: "o3-mini").displayName == "o3-mini")

        let gemini = AssistModelSpecification.specification(for: "gemini-2.5-pro")
        #expect(gemini.provider == .openRouter && gemini.contextWindowTokens == 1_000_000)
        #expect(AssistModelSpecification.specification(for: "gemini-flash").displayName == "Gemini 3.8 Flash")

        #expect(AssistModelSpecification.specification(for: "codestral-latest").displayName == "Codestral")
        #expect(AssistModelSpecification.specification(for: "mistral-large").displayName == "Mistral Large")
        #expect(AssistModelSpecification.specification(for: "deepseek-chat").displayName == "DeepSeek V3")
        #expect(AssistModelSpecification.specification(for: "deepseek-chat").contextWindowTokens == 64_000)

        let codex = AssistModelSpecification.specification(for: "codex")
        #expect(codex.provider == .codex && codex.contextWindowTokens == 32_000)
        #expect(!codex.capabilities.contains(.toolCalling))

        let ollama = AssistModelSpecification.specification(for: "ollama:qwen2.5-coder")
        #expect(ollama.provider == .ollama && ollama.contextWindowTokens == 32_000)

        let apple = AssistModelSpecification.specification(for: "apple-foundation")
        #expect(apple.provider == .foundationModels && apple.capabilities == .localFoundation)

        let unknown = AssistModelSpecification.specification(for: "some-future-model-9")
        #expect(unknown.provider == .openRouter && unknown.contextWindowTokens == 128_000)
        #expect(unknown.capabilities == .standardCloud)
    }

    @Test func specificationNormalizesPrompts() {
        let withSystem = AssistModelSpecification.normalizePrompt(systemPrompt: "SYS", userInstructions: "DO", for: "gpt-4o")
        #expect(withSystem == "SYS\n\n# TASK EXECUTION INSTRUCTIONS\nDO")
        let merged = AssistModelSpecification.normalizePrompt(systemPrompt: "SYS", userInstructions: "DO", for: "codex")
        #expect(merged == "SYSTEM DIRECTIVES:\nSYS\n\nUSER REQUEST:\nDO")
    }

    @Test func contextBudget() {
        let budget = AgentModelContextBudget(modelId: "gpt-4o", contextWindowTokens: 128_000)
        #expect(budget.maxInputTokens == 128_000 - 4096)
        #expect(budget.estimatedTokenCount(for: "abcd") == 1)
        #expect(budget.estimatedTokenCount(for: String(repeating: "x", count: 400)) == 100)
        #expect(budget.fitsContext(estimatedTokens: budget.maxInputTokens))
        #expect(!budget.fitsContext(estimatedTokens: budget.maxInputTokens + 1))
        #expect(AssistModelSpecification.contextBudget(for: "claude-sonnet-4-5").contextWindowTokens == 200_000)
    }

    @Test func freeOnlyEligibility() {
        #expect(AssistModelEligibilityPolicy.isEligible(modelID: "openai/gpt-oss-120b:free", onlyUseFreeModels: true))
        #expect(AssistModelEligibilityPolicy.isEligible(modelID: "FREE-model", onlyUseFreeModels: true))
        #expect(!AssistModelEligibilityPolicy.isEligible(modelID: "gpt-4o", onlyUseFreeModels: true))
        #expect(!AssistModelEligibilityPolicy.isEligible(modelID: "", onlyUseFreeModels: true))
        #expect(!AssistModelEligibilityPolicy.isEligible(modelID: "   ", onlyUseFreeModels: true))
        #expect(AssistModelEligibilityPolicy.isEligible(modelID: "gpt-4o", onlyUseFreeModels: false))
        #expect(AssistModelEligibilityPolicy.filterEligibleModelIDs(["a:free", "b", "c:FREE"], onlyUseFreeModels: true) == ["a:free", "c:FREE"])
        #expect(throws: AssistModelEligibilityError.self) {
            try AssistModelEligibilityPolicy.validateExecutionEligibility(modelID: "gpt-4o", provider: "openai", onlyUseFreeModels: true)
        }
        try? AssistModelEligibilityPolicy.validateExecutionEligibility(modelID: "gpt-4o", onlyUseFreeModels: false)
    }

    @Test func openCodeModelID() {
        let parsed = OpenCodeModelID.parse("opencode:anthropic/claude-sonnet-4-5")
        #expect(parsed?.providerID == "anthropic" && parsed?.modelID == "claude-sonnet-4-5")
        #expect(parsed?.storedID == "opencode:anthropic/claude-sonnet-4-5")
        #expect(parsed?.displayName == "anthropic/claude-sonnet-4-5")
        #expect(OpenCodeModelID.parse("anthropic/claude-sonnet-4-5") == nil)
        #expect(OpenCodeModelID.parse("opencode:") == nil)
        #expect(OpenCodeModelID.parse("opencode:anthropic/") == nil)
        #expect(OpenCodeModelID.parse("opencode:/model") == nil)
        #expect(OpenCodeModelID.isOpenCodeModelID("opencode:a/b"))
        #expect(!OpenCodeModelID.isOpenCodeModelID("openrouter/a/b"))
    }

    @Test func hermesModelID() {
        let parsed = HermesModelID.parse("hermes:openrouter:meta-llama/llama-4")
        #expect(parsed?.spec == "openrouter:meta-llama/llama-4")
        #expect(parsed?.provider == "openrouter")
        #expect(parsed?.model == "meta-llama/llama-4")
        #expect(parsed?.storedID == "hermes:openrouter:meta-llama/llama-4")
        let bare = HermesModelID.parse("hermes:llama-4")
        #expect(bare?.provider == nil && bare?.model == "llama-4")
        #expect(HermesModelID.parse("hermes:") == nil)
        #expect(HermesModelID.parse("hermes:openrouter:") == nil)
        #expect(HermesModelID.parse("gpt-4o") == nil)
        #expect(HermesModelID.isHermesModelID("hermes:x"))
    }

    @Test func openCodeConfiguration() {
        var settings = AssistantSettings()
        settings.openCodeURL = "http://127.0.0.1:4096"
        settings.openCodeAgentName = "swiftcode"
        let config = OpenCodeConfiguration(settings: settings)
        #expect(config.serverURL.absoluteString == "http://127.0.0.1:4096")
        #expect(config.agentName == "swiftcode")
        #expect(config.isLoopback)
        #expect(config.port == 4096)

        var other = AssistantSettings()
        var custom = OpenCodeConfiguration(serverURL: URL(string: "https://example.invalid:8443")!, agentName: "custom", managedServerEnabled: true)
        #expect(!custom.isLoopback)
        #expect(custom.port == 8443)
        custom.apply(to: &other)
        #expect(other.openCodeURL == "https://example.invalid:8443")
        #expect(other.openCodeAgentName == "custom")

        #expect(OpenCodeConfiguration.swiftcodeAgentDefinition.contains("\"*\": deny"))
        #expect(OpenCodeConfiguration.swiftcodeAgentDefinition.contains("never runs tools itself"))
        #expect(OpenCodeConfiguration.defaultServerURL.absoluteString == "http://127.0.0.1:4096")
        #expect(OpenCodeConfiguration.defaultAgentName == "swiftcode")

        var broken = AssistantSettings()
        broken.openCodeURL = "not a url"
        #expect(OpenCodeConfiguration(settings: broken).serverURL == OpenCodeConfiguration.defaultServerURL)
    }

    @Test @MainActor func rankModelsPrefersSelectedThenFewestFailures() {
        let router = AssistModelRouter()
        let models = Self.openRouterCandidates().map { AssistAvailableModel(candidate: $0) }
        let ranked = router.rankModels(models: models, preferredIdentifier: "google/gemini-2.5-pro")
        #expect(ranked.first?.id == "google/gemini-2.5-pro")
        let plain = router.rankModels(models: models, preferredIdentifier: "")
        #expect(plain.map(\.id).contains("anthropic/claude-sonnet-4-5"))
        #expect(plain.map(\.id).contains("anthropic/claude-haiku-4-5"))
        #expect(plain.last?.id == "google/gemini-2.5-pro")
        router.failedAttemptsCount["anthropic/claude-sonnet-4-5"] = 3
        let withFailures = router.rankModels(models: models, preferredIdentifier: "")
        #expect(withFailures.map(\.id) == ["anthropic/claude-haiku-4-5", "google/gemini-2.5-pro", "anthropic/claude-sonnet-4-5"])
    }

    /// `candidates()`/`openRouterCandidates()` re-homed onto a local provider so
    /// `hasCredentials` always passes during eligibility filtering.
    static func localCandidates() -> [AssistCandidateModel] {
        candidates().map { candidate in
            var copy = candidate
            copy.provider = .ollama
            return copy
        }
    }

    static func localOpenRouterCandidates() -> [AssistCandidateModel] {
        openRouterCandidates().map { candidate in
            var copy = candidate
            copy.provider = .ollama
            return copy
        }
    }

    @Test @MainActor func eligibleCandidatesFilter() async {
        let restore = Self.useFailoverEnvironment(Self.localCandidates(), autoSwitch: true)
        defer { restore() }
        let router = AssistModelRouter()
        let eligible = await router.getEligibleCandidates()
        #expect(eligible.map(\.id) == ["my-fine-tune", "anthropic/claude-sonnet-4-5", "gpt-4o"])
    }

    @Test @MainActor func eligibleCandidatesExcludeCustomWhenProviderModelsOnly() async {
        let restore = Self.useFailoverEnvironment(Self.localCandidates(), autoSwitch: true)
        defer { restore() }
        AppSettings.shared.assistUseProviderModels = true
        let router = AssistModelRouter()
        let eligible = await router.getEligibleCandidates()
        #expect(!eligible.contains { $0.source == .custom })
        #expect(eligible.map(\.id) == ["anthropic/claude-sonnet-4-5", "gpt-4o"])
    }

    @Test @MainActor func eligibleCandidatesAppendCloudAfterAgenticFilter() async {
        let restore = Self.useFailoverEnvironment(Self.localOpenRouterCandidates(), autoSwitch: true)
        defer { restore() }
        AppSettings.shared.useSwiftCodeCloudModel = true
        let router = AssistModelRouter()
        let eligible = await router.getEligibleCandidates()
        let cloud = eligible.last
        #expect(cloud != nil)
        #expect(SCCloudConfiguration.isCloudModelID(cloud?.id ?? ""))
        #expect(cloud?.providerID == SCCloudConfiguration.providerID)
        #expect(cloud?.supportsToolCalling == false)
        #expect(cloud?.statusDescription.contains("left today") == true)
    }

    @Test @MainActor func eligibleCandidatesExcludeQuarantined() async {
        let restore = Self.useFailoverEnvironment(Self.localOpenRouterCandidates(), autoSwitch: true)
        defer { restore() }
        let router = AssistModelRouter()
        router.markRateLimited(modelID: "anthropic/claude-sonnet-4-5")
        var eligible = await router.getEligibleCandidates()
        #expect(!eligible.contains { $0.id == "anthropic/claude-sonnet-4-5" })
        router.markModelHealthy(modelID: "anthropic/claude-sonnet-4-5")
        eligible = await router.getEligibleCandidates()
        #expect(eligible.contains { $0.id == "anthropic/claude-sonnet-4-5" })
    }

    @Test @MainActor func resolveDefaultModel() async {
        let router = AssistModelRouter()
        let settings = AppSettings.shared
        let discovery = AssistModelDiscoveryService.shared
        let savedSelected = settings.selectedAssistModelID
        let savedCloud = settings.useSwiftCodeCloudModel
        let savedModels = discovery.discoveredModels
        let savedDate = discovery.lastDiscoveryDate
        defer {
            discovery.discoveredModels = savedModels
            discovery.lastDiscoveryDate = savedDate
            settings.selectedAssistModelID = savedSelected
            settings.useSwiftCodeCloudModel = savedCloud
        }
        let discovered = Self.openRouterCandidates()

        discovery.discoveredModels = discovered.map { AssistAvailableModel(candidate: $0) }
        discovery.lastDiscoveryDate = Date()
        settings.useSwiftCodeCloudModel = true
        settings.selectedAssistModelID = "swiftcode-cloud:qwen3"
        let cloud = await router.resolveDefaultModel()
        #expect(cloud.providerID == SCCloudConfiguration.providerID)
        #expect(cloud.id == "swiftcode-cloud:qwen3")
        #expect(cloud.modelIdentifier == "qwen3")
        #expect(cloud.statusDescription.contains("left today"))

        settings.useSwiftCodeCloudModel = false
        settings.selectedAssistModelID = "anthropic/claude-haiku-4-5"
        let match = await router.resolveDefaultModel()
        #expect(match.id == "anthropic/claude-haiku-4-5" && match.displayName == "Claude Haiku")

        discovery.discoveredModels = []
        settings.selectedAssistModelID = "afm-3-core"
        let afm = await router.resolveDefaultModel()
        #expect(afm.providerID == "apple")
        #expect(afm.source == .appleFoundation)
        #expect(afm.contextWindow == 16_000)
        #expect(afm.statusDescription == "On-Device Available (Chat Mode Only)")

        settings.selectedAssistModelID = "gpt-4o"
        let spec = await router.resolveDefaultModel()
        #expect(spec.providerID == "openai" && spec.displayName == "GPT-4o")
        #expect(spec.source == .openAI)
    }

    @Test @MainActor func selectNextModel() async {
        let restore = Self.useFailoverEnvironment(Self.localFailoverCandidates(), autoSwitch: true)
        defer { restore() }
        let router = AssistModelRouter()
        #expect(await router.selectNextModel(excluding: ["anthropic/claude-sonnet-4-5"])?.id == "anthropic/claude-haiku-4-5")
        #expect(await router.selectNextModel(excluding: Set(Self.localFailoverCandidates().map(\.id))) == nil)
    }

    @Test @MainActor func classifyFailures() {
        struct E: LocalizedError { let message: String; var errorDescription: String? { message } }
        #expect(AssistModelRouter.classify(error: E(message: "HTTP 429 too many requests")) == .quotaExhausted)
        #expect(AssistModelRouter.classify(error: E(message: "rate_limit exceeded")) == .quotaExhausted)
        #expect(AssistModelRouter.classify(error: E(message: "quota exceeded for model")) == .quotaExhausted)
        #expect(AssistModelRouter.classify(error: E(message: "401 invalid api key")) == .authenticationFailed)
        #expect(AssistModelRouter.classify(error: E(message: "unauthorized")) == .authenticationFailed)
        #expect(AssistModelRouter.classify(error: E(message: "request timed out")) == .timeout)
        #expect(AssistModelRouter.classify(error: E(message: "cannot connect to server")) == .networkFailure)
        #expect(AssistModelRouter.classify(error: E(message: "model not found")) == .modelUnavailable)
        #expect(AssistModelRouter.classify(error: E(message: "HTTP 404")) == .modelUnavailable)
        #expect(AssistModelRouter.classify(error: E(message: "HTTP 503 overloaded")) == .providerUnavailable)
        #expect(AssistModelRouter.classify(error: E(message: "something strange happened")) == .internalAntigravityFailure)
        #expect(AssistModelRouter.isQuotaOrRateLimit(errorText: "429 Too Many Requests"))
        #expect(!AssistModelRouter.isQuotaOrRateLimit(errorText: "bad request"))
    }

    @Test @MainActor func quarantineLifecycle() {
        let router = AssistModelRouter()
        #expect(router.isModelQuarantined(modelIdentifier: "gpt-4o") == false)
        router.markRateLimited(modelID: "gpt-4o")
        #expect(router.isModelQuarantined(modelIdentifier: "gpt-4o"))
        router.markModelHealthy(modelID: "gpt-4o")
        #expect(router.isModelQuarantined(modelIdentifier: "gpt-4o") == false)

        router.markAuthenticationFailed(modelID: "gpt-4o")
        #expect(router.isModelQuarantined(modelIdentifier: "gpt-4o"))
        router.markModelUnavailable(modelID: "gpt-4o", reason: "gone")
        #expect(router.failedAttemptsCount["gpt-4o"] == 1)
        router.clearAllQuarantines()
        #expect(router.isModelQuarantined(modelIdentifier: "gpt-4o") == false)
        #expect(router.failedAttemptsCount.isEmpty)
        #expect(router.quarantinedModels.isEmpty)
    }

    /// Candidates on a local provider so `hasCredentials` always passes in
    /// tests; ranking still exercises priority/failure ordering.
    static func localFailoverCandidates() -> [AssistCandidateModel] {
        [
            AssistCandidateModel(id: "anthropic/claude-sonnet-4-5", displayName: "Claude Sonnet",
                                 provider: .ollama, priority: 5, source: .provider),
            AssistCandidateModel(id: "anthropic/claude-haiku-4-5", displayName: "Claude Haiku",
                                 provider: .ollama, priority: 5, source: .provider),
            AssistCandidateModel(id: "google/gemini-2.5-pro", displayName: "Gemini Pro",
                                 provider: .ollama, contextWindow: 1_000_000, priority: 10,
                                 source: .provider),
        ]
    }

    /// Points the shared discovery service at `models` and applies the
    /// settings the failover path reads. Returns a restore closure.
    @MainActor
    static func useFailoverEnvironment(_ models: [AssistCandidateModel],
                                       autoSwitch: Bool) -> @MainActor () -> Void {
        let discovery = AssistModelDiscoveryService.shared
        let settings = AppSettings.shared
        let savedModels = discovery.discoveredModels
        let savedDate = discovery.lastDiscoveryDate
        let savedSwitch = settings.assistAutomaticallySwitchModels
        let savedStrategy = settings.assistModelRoutingStrategy
        let savedCloud = settings.useSwiftCodeCloudModel
        let savedProviderModels = settings.assistUseProviderModels
        let savedSelected = settings.selectedAssistModelID
        discovery.discoveredModels = models.map { AssistAvailableModel(candidate: $0) }
        discovery.lastDiscoveryDate = Date()
        settings.assistModelRoutingStrategy = "app_models"
        settings.assistAutomaticallySwitchModels = autoSwitch
        settings.useSwiftCodeCloudModel = false
        settings.assistUseProviderModels = false
        settings.selectedAssistModelID = ""
        return {
            discovery.discoveredModels = savedModels
            discovery.lastDiscoveryDate = savedDate
            settings.assistAutomaticallySwitchModels = savedSwitch
            settings.assistModelRoutingStrategy = savedStrategy
            settings.useSwiftCodeCloudModel = savedCloud
            settings.assistUseProviderModels = savedProviderModels
            settings.selectedAssistModelID = savedSelected
        }
    }

    @Test @MainActor func handleTurnFailureRespectsAutoSwitchOff() async {
        struct E: LocalizedError { let message: String; var errorDescription: String? { message } }
        let restore = Self.useFailoverEnvironment(Self.localFailoverCandidates(), autoSwitch: false)
        defer { restore() }
        let router = AssistModelRouter()
        let models = Self.localFailoverCandidates()
        let failed = AssistAvailableModel(candidate: models[0])
        let result = await router.handleTurnFailure(
            failedModel: failed, error: E(message: "HTTP 429"), completedTurnContent: "partial",
            executedToolsCount: 2, objective: "Fix the bug"
        )
        #expect(result == nil)
        #expect(router.isModelQuarantined(modelIdentifier: failed.id))
    }

    @Test @MainActor func handleTurnFailureFailsOverWithHandoff() async throws {
        struct E: LocalizedError { let message: String; var errorDescription: String? { message } }
        let restore = Self.useFailoverEnvironment(Self.localFailoverCandidates(), autoSwitch: true)
        defer { restore() }
        let router = AssistModelRouter()
        let models = Self.localFailoverCandidates()
        let failed = AssistAvailableModel(candidate: models[0])
        let result = await router.handleTurnFailure(
            failedModel: failed, error: E(message: "boom"), completedTurnContent: "half the fix",
            executedToolsCount: 2, objective: "Fix the bug"
        )
        let next = try #require(result)
        #expect(next.nextModel.id == "anthropic/claude-haiku-4-5")
        #expect(next.continuationPrompt.contains("CONTINUATION DIRECTIVE:"))
        #expect(next.continuationPrompt.contains("half the fix"))
        #expect(next.continuationPrompt.contains("Previous actions executed 2 tool calls"))
        #expect(next.continuationPrompt.contains("without repeating already completed work"))
        let event = router.lastFailoverEvent
        #expect(event?.failedModelID == failed.modelIdentifier)
        #expect(event?.newModelID == "anthropic/claude-haiku-4-5")
        #expect(router.failoverHistory.count == 1)
    }

    @Test @MainActor func handleTurnFailureQuotaExcludesWholeProvider() async {
        struct E: LocalizedError { let message: String; var errorDescription: String? { message } }
        let restore = Self.useFailoverEnvironment(Self.localFailoverCandidates(), autoSwitch: true)
        defer { restore() }
        let router = AssistModelRouter()
        let failed = AssistAvailableModel(candidate: Self.localFailoverCandidates()[0])
        let result = await router.handleTurnFailure(
            failedModel: failed, error: E(message: "HTTP 429"), completedTurnContent: "",
            executedToolsCount: 0, objective: "x"
        )
        #expect(result == nil)
    }

    @Test @MainActor func handleTurnFailureExhaustedReturnsNil() async {
        struct E: LocalizedError { let message: String; var errorDescription: String? { message } }
        let only = [Self.localFailoverCandidates()[0]]
        let restore = Self.useFailoverEnvironment(only, autoSwitch: true)
        defer { restore() }
        let router = AssistModelRouter()
        let failed = AssistAvailableModel(candidate: only[0])
        let result = await router.handleTurnFailure(
            failedModel: failed, error: E(message: "boom"), completedTurnContent: "",
            executedToolsCount: 0, objective: "x"
        )
        #expect(result == nil)
    }

    @Test @MainActor func continuationPrompt() {
        let router = AssistModelRouter()
        let prompt = router.buildContinuationPrompt(
            originalPrompt: "Fix the bug", priorTurnOutput: "half the fix", failedModelName: "GPT-4o"
        )
        #expect(prompt.hasPrefix("CONTINUATION DIRECTIVE:\n"))
        #expect(prompt.contains("The previous model (GPT-4o) encountered an interruption or rate limit and failed."))
        #expect(prompt.contains("DO NOT repeat or overwrite work"))
        #expect(prompt.contains("Original Objective:\nFix the bug"))
        let empty = router.buildContinuationPrompt(originalPrompt: "x", priorTurnOutput: "  ", failedModelName: "m")
        #expect(!empty.contains("Partial response"))
    }

    @Test @MainActor func userProvidedModels() {
        let custom = AssistCandidateModel(id: "my-model", displayName: "Mine", provider: .openRouter, source: .custom)
        let customAvailable = AssistAvailableModel(candidate: custom)
        #expect(AssistModelRouter.isUserProvidedModel(customAvailable))
        let cloud = AssistCandidateModel(id: "swiftcode-cloud", displayName: "Cloud", provider: .scCloud, source: .cloud)
        #expect(!AssistModelRouter.isUserProvidedModel(AssistAvailableModel(candidate: cloud)))

        let settings = AppSettings.shared
        let savedCustomModel = settings.customModel
        defer { settings.customModel = savedCustomModel }
        settings.customModel = "my-model"
        #expect(AssistModelRouter.isUserProvidedSelectedModelID("my-model", discovered: nil))
        settings.customModel = "other-model"
        #expect(!AssistModelRouter.isUserProvidedSelectedModelID("my-model", discovered: nil))
        settings.customModel = "my-model"
        #expect(!AssistModelRouter.isUserProvidedSelectedModelID("", discovered: nil))
        #expect(!AssistModelRouter.isUserProvidedSelectedModelID("swiftcode-cloud:qwen3", discovered: nil))
        #expect(!AssistModelRouter.isUserProvidedSelectedModelID("hermes:llama", discovered: nil))
        #expect(!AssistModelRouter.isUserProvidedSelectedModelID("opencode:a/b", discovered: nil))
        #expect(AssistModelRouter.isUserProvidedSelectedModelID("whatever", discovered: customAvailable))
    }

    @Test func providerKindForModelID() {
        let backends = AssistantBackends(settings: AssistantSettings(), store: MemorySecretStore(), account: nil)
        #expect(backends.providerKind(forModelID: "hermes:llama-4") == .hermes)
        #expect(backends.providerKind(forModelID: "opencode:anthropic/claude-sonnet-4-5") == .openCode)
        #expect(backends.providerKind(forModelID: "swiftcode-cloud:qwen3") == .scCloud)
        #expect(backends.providerKind(forModelID: "swiftcode-cloud") == .scCloud)
        #expect(backends.providerKind(forModelID: "gpt-4o") == .openAI)
        #expect(backends.providerKind(forModelID: "claude-sonnet-4-5") == .openRouter)
        #expect(backends.providerKind(forModelID: "codex") == .codex)
        #expect(backends.providerKind(forModelID: "ollama:qwen2.5-coder") == .ollama)
        #expect(backends.providerKind(forModelID: "apple-foundation") == .foundationModels)
        #expect(backends.provider(forModelID: "opencode:a/b").kind == .openCode)
        #expect(backends.provider(forModelID: "hermes:x").kind == .hermes)
        #expect(backends.provider(forModelID: "swiftcode-cloud").kind == .scCloud)
        #expect(backends.provider(forModelID: "muse-wonder-1.0").kind == .openRouter)
    }

    @Test func assistantSettingsRoutingDefaults() {
        let settings = AssistantSettings()
        #expect(settings.routingStrategy == .providerDefault)
        #expect(settings.automaticallySwitchModels == true)
        #expect(settings.useProviderModelsOnly == false)
        #expect(settings.onlyUseFreeModels == false)
        #expect(settings.useSwiftCodeCloudModel == false)
        #expect(settings.openCodeAgentName == "swiftcode")
        #expect(settings.customModelID == "")
    }

    @Test func assistantSettingsRoutingRoundTrip() throws {
        var settings = AssistantSettings()
        settings.routingStrategy = .appModels
        settings.automaticallySwitchModels = false
        settings.useProviderModelsOnly = true
        settings.onlyUseFreeModels = true
        settings.useSwiftCodeCloudModel = true
        settings.openCodeAgentName = "custom-agent"
        settings.customModelID = "my-model"
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AssistantSettings.self, from: data)
        #expect(decoded == settings)
    }

    @Test func assistantSettingsUnknownStrategyDecodesToDefault() throws {
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(AssistantSettings())) as! [String: Any]
        json["routingStrategy"] = "rotation"
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(AssistantSettings.self, from: data)
        #expect(decoded.routingStrategy == .providerDefault)
        #expect(AssistRoutingStrategy.lenient("rotation") == .providerDefault)
        #expect(AssistRoutingStrategy.lenient("app_models") == .appModels)
        #expect(AssistRoutingStrategy.lenient(nil) == .providerDefault)
        #expect(AssistRoutingStrategy.lenient("nonsense") == .providerDefault)
    }

    @Test func assistantSettingsMissingKeysKeepDefaults() throws {
        let data = try JSONSerialization.data(withJSONObject: ["provider": "openAI"])
        let decoded = try JSONDecoder().decode(AssistantSettings.self, from: data)
        #expect(decoded.provider == .openAI)
        #expect(decoded.routingStrategy == .providerDefault)
        #expect(decoded.automaticallySwitchModels == true)
    }
}

@Suite struct MetaAssistProviderTests {
    @Test func fallbackCatalog() {
        #expect(MetaAssistProvider.fallbackModels.count == 6)
        #expect(MetaAssistProvider.defaultModelID == "muse-wonder-1.0")
        let first = MetaAssistProvider.fallbackModels[0]
        #expect(first.modelId == "muse-wonder-1.0" && first.isDefault)
        #expect(first.contextLimit == 1_000_000 && first.outputLimit == 128_000)
        #expect(first.defaultReasoningEffort == "high")
        #expect(MetaAssistProvider.fallbackModels[1].modelId == "muse-spark-1.3")
        #expect(MetaAssistProvider.providerID == "meta_assist")
        #expect(MetaAssistProvider.providerName == "Assist with Meta")
        #expect(ProviderKind.metaAssist.displayName == "Assist with Meta")
    }

    @Test func metaAssistIsDispatchedByBackends() {
        let backends = AssistantBackends(settings: AssistantSettings(), store: MemorySecretStore(), account: nil)
        #expect(backends.provider(.metaAssist).kind == .metaAssist)
        #expect(ProviderKind.allCases.contains(.metaAssist))
    }
}
