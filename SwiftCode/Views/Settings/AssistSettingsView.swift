import SwiftUI

public struct AssistSettingsView: View {
    @AppStorage("assist.safetyLevel") private var safetyLevel = AssistSafetyLevel.balanced.rawValue
    @AppStorage("assist.isAutonomous") private var isAutonomous = true
    @AppStorage("assist.takeoverEnabled") private var takeoverEnabled = false
    @AppStorage("assist.debugMode") private var debugMode = false
    @AppStorage("assist.selectedProvider") private var selectedProvider = AssistModelProvider.openAI.rawValue

    @StateObject private var manager = AssistManager.shared
    @State private var apiKey: String = ""
    @State private var testResult: String?
    @State private var isTesting = false

    public var body: some View {
        Form {
            Section {
                Toggle("Autonomous Execution", isOn: $isAutonomous)

                if isAutonomous {
                    Toggle("Assist Takeovers", isOn: $takeoverEnabled)
                }

                Picker("Safety Level", selection: $safetyLevel) {
                    ForEach(AssistSafetyLevel.allCases, id: \.rawValue) { level in
                        Text(level.rawValue).tag(level.rawValue)
                    }
                }
            } header: {
                Text("Execution Mode")
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("In autonomous mode, the agent will execute plans without requesting confirmation for each step.")
                    if takeoverEnabled {
                        Text("This feature is highly experimental and may be unstable on large codebases. Assist will operate without human input and make autonomous changes.")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }
                }
            }

            Section("AI Model & Provider") {
                Picker("Provider", selection: $selectedProvider) {
                    ForEach(AssistModelProvider.allCases, id: \.rawValue) { provider in
                        Text(provider.rawValue).tag(provider.rawValue)
                    }
                }
                .onChange(of: selectedProvider) { _ in
                    loadApiKey()
                }

                Picker("Model", selection: $AppSettings.shared.selectedAssistModelID) {
                    if let provider = AssistModelProvider(rawValue: selectedProvider) {
                        switch provider {
                        case .openAI:
                            Text("GPT-4o").tag("openai/gpt-4o")
                            Text("GPT-4o mini").tag("openai/gpt-4o-mini")
                        case .anthropic:
                            Text("Claude 3.5 Sonnet").tag("anthropic/claude-3.5-sonnet")
                            Text("Claude 3 Opus").tag("anthropic/claude-3-opus")
                        case .gemini:
                            Text("Gemini Pro 1.5").tag("google/gemini-pro-1.5")
                        case .openRouter:
                            Text("Claude 3.5 Sonnet (OR)").tag("anthropic/claude-3.5-sonnet")
                            Text("GPT-4o (OR)").tag("openai/gpt-4o")
                            Text("Llama 3.1 405B").tag("meta-llama/llama-3.1-405b")
                        default:
                            Text("Default").tag("default")
                        }
                    }
                }

                SecureField("API Key", text: $apiKey)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .onAppear { loadApiKey() }

                Button(action: saveApiKey) {
                    Text("Save API Key")
                }

                Button(action: testApiKey) {
                    HStack {
                        Text("Test API Connection")
                        if isTesting {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(apiKey.isEmpty || isTesting)

                if let result = testResult {
                    Text(result)
                        .font(.caption)
                        .foregroundColor(result.contains("Success") ? .green : .red)
                }
            }

            Section {
                Toggle("Debug Mode", isOn: $debugMode)
                if debugMode {
                    NavigationLink("View Tool Logs") {
                        AssistLogsDetailView(logger: manager.logger)
                    }
                }
            } header: {
                Text("Developer")
            }

            Section("Available Tools") {
                ForEach(manager.registry.allTools, id: \.id) { tool in
                    VStack(alignment: .leading) {
                        Text(tool.name).font(.headline)
                        Text(tool.description).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Assist Settings")
    }

    private func loadApiKey() {
        if let provider = AssistModelProvider(rawValue: selectedProvider) {
            apiKey = APIKeyManager.shared.retrieveKey(service: provider.apiKeyProvider) ?? ""
        }
    }

    private func saveApiKey() {
        if let provider = AssistModelProvider(rawValue: selectedProvider) {
            APIKeyManager.shared.storeKey(service: provider.apiKeyProvider, key: apiKey)
        }
    }

    private func testApiKey() {
        guard let provider = AssistModelProvider(rawValue: selectedProvider) else { return }
        isTesting = true
        testResult = nil

        Task {
            let response = await AssistLLMService.generateResponse(prompt: "Hello, this is a test.", provider: provider, apiKey: apiKey)
            await MainActor.run {
                testResult = response.success ? "Success: API connection verified!" : "Error: \(response.error ?? "Unknown error")"
                isTesting = false
            }
        }
    }
}

struct AssistLogsDetailView: View {
    @ObservedObject var logger: AssistLogger

    var body: some View {
        List(logger.logs) { entry in
            VStack(alignment: .leading) {
                HStack {
                    Text(entry.level.rawValue)
                        .font(.caption2.bold())
                        .padding(4)
                        .background(color(for: entry.level))
                        .clipShape(Capsule())

                    if let toolId = entry.toolId {
                        Text("[\(toolId)]").font(.caption2).monospaced()
                    }

                    Spacer()
                    Text(entry.timestamp, style: .time).font(.caption2).foregroundStyle(.secondary)
                }
                Text(entry.message).font(.subheadline)
            }
        }
        .navigationTitle("Assist Logs")
    }

    private func color(for level: AssistLogLevel) -> Color {
        switch level {
        case .info: return .blue.opacity(0.2)
        case .warning: return .orange.opacity(0.2)
        case .error: return .red.opacity(0.2)
        case .debug: return .gray.opacity(0.2)
        }
    }
}
