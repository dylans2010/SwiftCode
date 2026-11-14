import Foundation
import YcodeAssistant









public enum DecompileAssistProviderPolicy {

    
    
    
    
    
    
    
    public static func resolveConfiguration(objective: String = "") async throws -> GoogleCloudSDKConfiguration {
        
        if let token = await GoogleAccountAuthService.shared.getValidAccessToken(),
           !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            var config = await baseConfiguration(objective: objective)
            config.oauthToken = token
            config.apiKey = nil
            config.executionMode = "antigravity"
            config.provider = "google"
            try validate(config)
            return config
        }

        
        var apiKey = await AssistModelRouter.shared.resolveAPIKey(for: "google")
        if apiKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
            apiKey = await APIKeyManager.shared.retrieveKey(service: .google)
        }
        if let apiKey, !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            var config = await baseConfiguration(objective: objective)
            config.apiKey = apiKey
            config.oauthToken = nil
            config.executionMode = "api_key"
            config.provider = "google"
            try validate(config)
            return config
        }

        throw DecompilerError.engineUnavailable(
            "Decompile Assist requires the Antigravity provider: sign in with Google or configure a Gemini API key in Assist Settings"
        )
    }

    
    
    public static func validate(_ config: GoogleCloudSDKConfiguration) throws {
        let provider = (config.provider ?? "").lowercased()
        let executionMode = (config.executionMode ?? "").lowercased()
        let model = config.model.lowercased()

        let isGoogleProvider = provider == "google" || provider == "gemini" || provider.isEmpty
        let isAntigravityMode = executionMode == "antigravity" || executionMode == "api_key"
        let isGeminiModel = model.hasPrefix("gemini-")

        guard isGoogleProvider, isAntigravityMode, isGeminiModel else {
            throw DecompilerError.invalidRequest(
                "Decompile Assist only supports the Antigravity provider with a gemini-* model " +
                "(provider=\(config.provider ?? "nil"), executionMode=\(config.executionMode ?? "nil"), model=\(config.model))"
            )
        }
    }

    

    private static func baseConfiguration(objective: String) async -> GoogleCloudSDKConfiguration {
        let model = await preferredModel()
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let storage = appSupport.appendingPathComponent("SwiftCode/GoogleCloudSDK", isDirectory: true)
        let brain = storage.appendingPathComponent("brain", isDirectory: true)
        let persistence = storage.appendingPathComponent("persistence", isDirectory: true)
        try? FileManager.default.createDirectory(at: brain, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: persistence, withIntermediateDirectories: true)

        return GoogleCloudSDKConfiguration(
            model: model,
            apiKey: nil,
            oauthToken: nil,
            executionMode: nil,
            userProject: nil,
            vertex: false,
            project: nil,
            location: nil,
            systemInstructions: nil,
            skillsPaths: [],
            workspaces: [],
            appDataDir: brain.path,
            saveDir: persistence.path,
            enableSubagents: false,
            maxSubagentDepth: 1,
            allowedSubagents: nil,
            serviceTier: .standard,
            tools: nil,
            provider: "google",
            baseURL: nil,
            thinkingLevel: nil,
            useSavedModels: false,
            toolkit: "System",
            downloadIfMissing: false,
            enableSpeculativeDecoding: false
        )
    }

    
    
    
    private static func preferredModel() async -> String {
        let configured = await DecompileAssistConfiguration.shared.modelOverride
        let override = configured?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !override.isEmpty {
            return override
        }
        if let gemini = AntigravitySDKModelFetcher.seedModels.first(where: {
            $0.id.lowercased().hasPrefix("gemini-")
        }) {
            return gemini.id
        }
        return "gemini-3.8-flash"
    }
}
