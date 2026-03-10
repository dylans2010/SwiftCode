import SwiftUI

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var selectedModel: String {
        didSet { UserDefaults.standard.set(selectedModel, forKey: "selectedModel") }
    }
    @Published var autoSave: Bool {
        didSet { UserDefaults.standard.set(autoSave, forKey: "autoSave") }
    }
    @Published var editorFontSize: Double {
        didSet { UserDefaults.standard.set(editorFontSize, forKey: "editorFontSize") }
    }
    @Published var useDarkTheme: Bool {
        didSet { UserDefaults.standard.set(useDarkTheme, forKey: "useDarkTheme") }
    }

    private init() {
        selectedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "anthropic/claude-3.5-sonnet"
        autoSave = UserDefaults.standard.object(forKey: "autoSave") as? Bool ?? true
        editorFontSize = UserDefaults.standard.object(forKey: "editorFontSize") as? Double ?? 14
        useDarkTheme = UserDefaults.standard.object(forKey: "useDarkTheme") as? Bool ?? true
    }
}

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var openRouterKey: String = ""
    @State private var githubToken: String = ""
    @State private var showOpenRouterKey = false
    @State private var showGitHubToken = false
    @State private var keySaved = false
    @State private var tokenSaved = false

    var body: some View {
        NavigationStack {
            Form {
                // AI Settings
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("OpenRouter API Key")
                                .font(.headline)
                            if openRouterKey.isEmpty {
                                Text("Not set")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            } else {
                                Text("••••••••\(String(openRouterKey.suffix(4)))")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }
                        Spacer()
                        Button {
                            showOpenRouterKey.toggle()
                        } label: {
                            Image(systemName: showOpenRouterKey ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    if showOpenRouterKey {
                        TextField("sk-or-xxxxxxxxxxxxxxxx", text: $openRouterKey)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .font(.system(.body, design: .monospaced))

                        Button {
                            KeychainService.shared.set(openRouterKey, forKey: KeychainService.openRouterAPIKey)
                            keySaved = true
                            showOpenRouterKey = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                keySaved = false
                            }
                        } label: {
                            Label(keySaved ? "Saved!" : "Save Key", systemImage: keySaved ? "checkmark.circle.fill" : "key.fill")
                                .foregroundStyle(keySaved ? .green : .orange)
                        }
                    }

                    Picker("Default AI Model", selection: $settings.selectedModel) {
                        ForEach(OpenRouterModel.defaults) { model in
                            Text(model.name).tag(model.id)
                        }
                    }
                } header: {
                    Label("AI Configuration", systemImage: "sparkles")
                }

                // GitHub Settings
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("GitHub Personal Access Token")
                                .font(.headline)
                            if githubToken.isEmpty {
                                Text("Not set")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            } else {
                                Text("••••••••\(String(githubToken.suffix(4)))")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }
                        Spacer()
                        Button {
                            showGitHubToken.toggle()
                        } label: {
                            Image(systemName: showGitHubToken ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    if showGitHubToken {
                        TextField("ghp_xxxxxxxxxxxx", text: $githubToken)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .font(.system(.body, design: .monospaced))

                        Button {
                            KeychainService.shared.set(githubToken, forKey: KeychainService.githubToken)
                            tokenSaved = true
                            showGitHubToken = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                tokenSaved = false
                            }
                        } label: {
                            Label(tokenSaved ? "Saved!" : "Save Token", systemImage: tokenSaved ? "checkmark.circle.fill" : "key.fill")
                                .foregroundStyle(tokenSaved ? .green : .blue)
                        }
                    }
                } header: {
                    Label("GitHub", systemImage: "arrow.triangle.2.circlepath")
                }

                // Editor Settings
                Section {
                    Toggle("Auto-Save", isOn: $settings.autoSave)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Font Size")
                            Spacer()
                            Text("\(Int(settings.editorFontSize))pt")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $settings.editorFontSize, in: 10...24, step: 1)
                            .tint(.orange)
                    }

                    Toggle("Dark Theme", isOn: $settings.useDarkTheme)
                } header: {
                    Label("Editor", systemImage: "doc.text")
                }

                // About
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("1")
                            .foregroundStyle(.secondary)
                    }
                    Link(destination: URL(string: "https://openrouter.ai")!) {
                        Label("OpenRouter API", systemImage: "link")
                    }
                    Link(destination: URL(string: "https://docs.github.com/en/rest")!) {
                        Label("GitHub API Docs", systemImage: "link")
                    }
                } header: {
                    Label("About SwiftCode", systemImage: "info.circle")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                openRouterKey = KeychainService.shared.get(forKey: KeychainService.openRouterAPIKey) ?? ""
                githubToken = KeychainService.shared.get(forKey: KeychainService.githubToken) ?? ""
            }
        }
    }
}
