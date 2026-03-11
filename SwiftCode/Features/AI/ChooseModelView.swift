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

                Section("Test Model") {
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
                        Text(result)
                            .font(.caption)
                            .foregroundStyle(result.contains("Success") ? .green : .red)
                    }
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
            do {
                // Map our UI provider enum to AgentModelCheck provider
                let provider: AgentModelCheck.AIProvider
                switch selectedProvider {
                case .openRouter: provider = .openRouter
                case .anthropic: provider = .anthropic
                case .openai: provider = .openai
                case .google: provider = .google
                }

                // Fetch models using AgentModelCheck
                let models = try await AgentModelCheck.shared.fetchSupportedModels(
                    apiKey: apiKey,
                    provider: provider
                )

                await MainActor.run {
                    availableModels = models
                    isLoadingModels = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Error fetching models: \(error.localizedDescription)"
                    // Fall back to default models
                    let provider: AgentModelCheck.AIProvider
                    switch selectedProvider {
                    case .openRouter: provider = .openRouter
                    case .anthropic: provider = .anthropic
                    case .openai: provider = .openai
                    case .google: provider = .google
                    }
                    availableModels = provider.defaultModels
                    isLoadingModels = false
                }
            }
        }
    }

    private func testModel() {
        isTesting = true
        testResult = nil
        errorMessage = nil

        Task {
            // Map our UI provider enum to AgentModelCheck provider
            let provider: AgentModelCheck.AIProvider
            switch selectedProvider {
            case .openRouter: provider = .openRouter
            case .anthropic: provider = .anthropic
            case .openai: provider = .openai
            case .google: provider = .google
            }

            // Test the model using AgentModelCheck
            let result = await AgentModelCheck.shared.testModel(
                apiKey: apiKey,
                provider: provider,
                model: controller.selectedModel
            )

            await MainActor.run {
                switch result.status {
                case .success:
                    var message = "Success: \(result.message)"
                    if let latency = result.responseLatency {
                        message += " (Response time: \(String(format: "%.2f", latency))s)"
                    }
                    testResult = message

                case .invalid_key:
                    testResult = "Failed"
                    errorMessage = "Invalid API Key: \(result.message)"

                case .model_not_found:
                    testResult = "Failed"
                    errorMessage = "Model Not Found: \(result.message)"

                case .rate_limited:
                    testResult = "Failed"
                    errorMessage = "Rate Limited: \(result.message)"

                case .network_error:
                    testResult = "Failed"
                    errorMessage = "Network Error: \(result.message)"

                case .unknown_error:
                    testResult = "Failed"
                    errorMessage = "Error: \(result.message)"
                }

                isTesting = false
            }
        }
    }
}
