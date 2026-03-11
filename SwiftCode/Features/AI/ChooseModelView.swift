import SwiftUI

struct ChooseModelView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var controller: AgentController

    @State private var selectedProvider: AIProvider = .openRouter
    @State private var apiKey: String = ""
    @State private var availableModels: [String] = []
    @State private var isLoadingModels = false
    @State private var testResult: String?
    @State private var isTesting = false
    @State private var errorMessage: String?
    @State private var lastCheckResult: AgentModelCheckResult? = nil

    enum AIProvider: String, CaseIterable, Identifiable {
        case openRouter = "OpenRouter"
        case anthropic = "Anthropic"
        case openai = "OpenAI"
        case google = "Gemini"

        var id: String { self.rawValue }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("AI Provider") {
                    Picker("Provider", selection: $selectedProvider) {
                        ForEach(AIProvider.allCases) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .pickerStyle(.menu)

                    SecureField("API Key", text: $apiKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Section {
                    Button {
                        fetchModels()
                    } label: {
                        if isLoadingModels {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Text("Fetch Available Models")
                        }
                    }
                    .disabled(apiKey.isEmpty || isLoadingModels)

                    if !availableModels.isEmpty {
                        Picker("Model", selection: $controller.selectedModel) {
                            ForEach(availableModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                    }
                } header: {
                    Text("Model Selection")
                }

                Section {
                    Button {
                        testModel()
                    } label: {
                        if isTesting {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Text("Test Model")
                        }
                    }
                    .disabled(apiKey.isEmpty || controller.selectedModel.isEmpty || isTesting)

                    if let result = testResult {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(result)
                                .font(.caption.bold())
                                .foregroundStyle(result.contains("Success") ? .green : .red)

                            if let check = lastCheckResult {
                                Text("Latency: \(String(format: "%.2f", check.latency))s")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)

                                Text("Capabilities: \(check.modelCapability)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)

                                if !check.supportedModels.isEmpty {
                                    Text("Supported Models: \(check.supportedModels.count)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Test Model")
                }

                if let error = errorMessage {
                    Section("Error Log") {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Choose My Own Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSettings()
                        dismiss()
                    }
                    .disabled(apiKey.isEmpty || controller.selectedModel.isEmpty)
                }
            }
            .onAppear {
                loadCurrentSettings()
            }
        }
    }

    private func loadCurrentSettings() {
        // Load existing key for the selected provider if available
        if selectedProvider == .openRouter {
            apiKey = KeychainService.shared.get(forKey: KeychainService.openRouterAPIKey) ?? ""
        }
        // In a real implementation, we would load for other providers too
    }

    private func saveSettings() {
        if selectedProvider == .openRouter {
            KeychainService.shared.set(apiKey, forKey: KeychainService.openRouterAPIKey)
        }
        // Save provider-specific settings to AppSettings or similar
    }

    private func fetchModels() {
        isLoadingModels = true
        errorMessage = nil

        Task {
            let originalKey = KeychainService.shared.get(forKey: KeychainService.openRouterAPIKey)
            do {
                switch selectedProvider {
                case .openRouter:
                    KeychainService.shared.set(apiKey, forKey: KeychainService.openRouterAPIKey)
                    let models = try await OpenRouterService.shared.fetchModels()
                    await MainActor.run {
                        availableModels = models.map { $0.id }
                        isLoadingModels = false
                        if let key = originalKey {
                             KeychainService.shared.set(key, forKey: KeychainService.openRouterAPIKey)
                        }
                    }
                case .anthropic:
                    // Simulated Anthropic fetch - in reality would use their API
                    try await Task.sleep(nanoseconds: 500_000_000)
                    await MainActor.run {
                        availableModels = ["claude-3-5-sonnet-20240620", "claude-3-opus-20240229", "claude-3-haiku-20240307"]
                        isLoadingModels = false
                    }
                case .openai:
                    // Simulated OpenAI fetch
                    try await Task.sleep(nanoseconds: 500_000_000)
                    await MainActor.run {
                        availableModels = ["gpt-4o", "gpt-4-turbo", "gpt-3.5-turbo"]
                        isLoadingModels = false
                    }
                case .google:
                    // Simulated Gemini fetch
                    try await Task.sleep(nanoseconds: 500_000_000)
                    await MainActor.run {
                        availableModels = ["gemini-1.5-pro", "gemini-1.5-flash", "gemini-1.0-pro"]
                        isLoadingModels = false
                    }
                }
            } catch {
                if let key = originalKey {
                    KeychainService.shared.set(key, forKey: KeychainService.openRouterAPIKey)
                }
                await MainActor.run {
                    errorMessage = "Error fetching models: \(error.localizedDescription)"
                    isLoadingModels = false
                }
            }
        }
    }

    private func testModel() {
        isTesting = true
        testResult = nil
        errorMessage = nil
        lastCheckResult = nil

        Task {
            let result = await AgentModelCheck.shared.checkModel(
                provider: selectedProvider.rawValue,
                apiKey: apiKey,
                model: controller.selectedModel
            )

            await MainActor.run {
                lastCheckResult = result
                isTesting = false

                switch result.status {
                case .success:
                    testResult = "Success: Model verified."
                case .invalid_key:
                    testResult = "Failed: Invalid API Key."
                case .model_not_found:
                    testResult = "Failed: Model not found."
                case .rate_limited:
                    testResult = "Failed: Rate limited."
                case .network_error:
                    testResult = "Failed: Network error."
                }

                if result.status != .success {
                    errorMessage = result.modelCapability
                }
            }
        }
    }
}
