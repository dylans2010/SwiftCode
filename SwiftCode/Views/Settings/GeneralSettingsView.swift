import SwiftUI
import Foundation

// MARK: - API Key Models

enum APIKeyProvider: String, Codable, CaseIterable {
    case openRouter = "OpenRouter"
    case gitHub = "GitHub"
    case custom = "Custom"

    var icon: String {
        switch self {
        case .openRouter: return "cpu"
        case .gitHub: return "chevron.left.forwardslash.chevron.right"
        case .custom: return "key.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .openRouter: return .orange
        case .gitHub: return .primary
        case .custom: return .cyan
        }
    }
}

struct APIKeyEntry: Identifiable, Codable {
    var id: UUID
    var name: String
    var provider: APIKeyProvider
    var isDefault: Bool

    var keychainKey: String { "api_key_entry_\(id.uuidString)" }

    init(id: UUID = UUID(), name: String, provider: APIKeyProvider, isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.provider = provider
        self.isDefault = isDefault
    }
}

// MARK: - API Key Manager

final class APIKeyManager: ObservableObject {
    static let shared = APIKeyManager()

    @Published var keys: [APIKeyEntry] = [] {
        didSet { saveMetadata() }
    }

    private let metadataKey = "apiKeyEntries"

    private init() { loadMetadata() }

    private func saveMetadata() {
        if let data = try? JSONEncoder().encode(keys) {
            UserDefaults.standard.set(data, forKey: metadataKey)
        }
    }

    private func loadMetadata() {
        guard let data = UserDefaults.standard.data(forKey: metadataKey),
              let decoded = try? JSONDecoder().decode([APIKeyEntry].self, from: data) else { return }
        keys = decoded
    }

    func add(name: String, provider: APIKeyProvider, keyValue: String) {
        var entry = APIKeyEntry(name: name, provider: provider)
        if keys.isEmpty { entry.isDefault = true }
        KeychainService.shared.set(keyValue, forKey: entry.keychainKey)
        keys.append(entry)
        if entry.isDefault { syncDefaultKey(entry, value: keyValue) }
    }

    func update(_ entry: APIKeyEntry, keyValue: String) {
        KeychainService.shared.set(keyValue, forKey: entry.keychainKey)
        if entry.isDefault { syncDefaultKey(entry, value: keyValue) }
    }

    func delete(_ entry: APIKeyEntry) {
        KeychainService.shared.delete(forKey: entry.keychainKey)
        keys.removeAll { $0.id == entry.id }
        // If deleted key was default, make first remaining key default
        if entry.isDefault && !keys.isEmpty {
            keys[0].isDefault = true
            if let val = keyValue(for: keys[0]) { syncDefaultKey(keys[0], value: val) }
        }
    }

    func setDefault(_ entry: APIKeyEntry) {
        for i in keys.indices { keys[i].isDefault = keys[i].id == entry.id }
        if let val = keyValue(for: entry) { syncDefaultKey(entry, value: val) }
    }

    func keyValue(for entry: APIKeyEntry) -> String? {
        KeychainService.shared.get(forKey: entry.keychainKey)
    }

    private func syncDefaultKey(_ entry: APIKeyEntry, value: String) {
        switch entry.provider {
        case .openRouter:
            KeychainService.shared.set(value, forKey: KeychainService.openRouterAPIKey)
        case .gitHub:
            KeychainService.shared.set(value, forKey: KeychainService.githubToken)
        case .custom:
            break
        }
    }

    func reset() {
        for key in keys { KeychainService.shared.delete(forKey: key.keychainKey) }
        keys = []
    }
}

// MARK: - Theme Models

struct ThemeColors: Codable, Equatable {
    var background: String
    var editorText: String
    var syntaxKeyword: String
    var syntaxString: String
    var syntaxComment: String
    var syntaxType: String
    var accent: String
    var toolbar: String
    var panelBackground: String
}

struct AppTheme: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var isBuiltIn: Bool
    var colors: ThemeColors

    static let light = AppTheme(
        id: "light", name: "Light", isBuiltIn: true,
        colors: ThemeColors(
            background: "#FFFFFF", editorText: "#000000",
            syntaxKeyword: "#AD3DA4", syntaxString: "#C41A16",
            syntaxComment: "#007400", syntaxType: "#3900A0",
            accent: "#007AFF", toolbar: "#F2F2F7", panelBackground: "#F5F5F5"
        )
    )
    static let dark = AppTheme(
        id: "dark", name: "Dark", isBuiltIn: true,
        colors: ThemeColors(
            background: "#1A1A2E", editorText: "#DCDCDC",
            syntaxKeyword: "#FC5FA3", syntaxString: "#FC6A5D",
            syntaxComment: "#6C7986", syntaxType: "#5DD8FF",
            accent: "#FF9500", toolbar: "#1C1C1E", panelBackground: "#242430"
        )
    )
    static let monokai = AppTheme(
        id: "monokai", name: "Monokai", isBuiltIn: true,
        colors: ThemeColors(
            background: "#272822", editorText: "#F8F8F2",
            syntaxKeyword: "#F92672", syntaxString: "#E6DB74",
            syntaxComment: "#75715E", syntaxType: "#66D9EF",
            accent: "#A6E22E", toolbar: "#1E1F1C", panelBackground: "#3E3D32"
        )
    )
    static let dracula = AppTheme(
        id: "dracula", name: "Dracula", isBuiltIn: true,
        colors: ThemeColors(
            background: "#282A36", editorText: "#F8F8F2",
            syntaxKeyword: "#FF79C6", syntaxString: "#F1FA8C",
            syntaxComment: "#6272A4", syntaxType: "#8BE9FD",
            accent: "#BD93F9", toolbar: "#21222C", panelBackground: "#343746"
        )
    )
    static let oneDark = AppTheme(
        id: "one_dark", name: "One Dark", isBuiltIn: true,
        colors: ThemeColors(
            background: "#282C34", editorText: "#ABB2BF",
            syntaxKeyword: "#C678DD", syntaxString: "#98C379",
            syntaxComment: "#5C6370", syntaxType: "#61AFEF",
            accent: "#E06C75", toolbar: "#21252B", panelBackground: "#2C313A"
        )
    )
    static let solarized = AppTheme(
        id: "solarized", name: "Solarized Dark", isBuiltIn: true,
        colors: ThemeColors(
            background: "#002B36", editorText: "#839496",
            syntaxKeyword: "#859900", syntaxString: "#2AA198",
            syntaxComment: "#586E75", syntaxType: "#268BD2",
            accent: "#B58900", toolbar: "#073642", panelBackground: "#073642"
        )
    )

    static let builtIns: [AppTheme] = [.light, .dark, .monokai, .dracula, .oneDark, .solarized]
}

// MARK: - Color Hex Helpers

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255,
                  blue: Double(b) / 255, opacity: Double(a) / 255)
    }

    func toHex() -> String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

// MARK: - Theme Manager

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var customThemes: [AppTheme] = [] {
        didSet { save() }
    }

    private let defaultsKey = "customThemes"

    private init() { load() }

    var allThemes: [AppTheme] { AppTheme.builtIns + customThemes }

    func theme(for id: String) -> AppTheme? {
        allThemes.first { $0.id == id }
    }

    func add(_ theme: AppTheme) {
        var mutable = theme
        mutable.isBuiltIn = false
        customThemes.append(mutable)
    }

    func update(_ theme: AppTheme) {
        if let idx = customThemes.firstIndex(where: { $0.id == theme.id }) {
            customThemes[idx] = theme
        }
    }

    func delete(_ theme: AppTheme) {
        customThemes.removeAll { $0.id == theme.id }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(customThemes) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([AppTheme].self, from: data) else { return }
        customThemes = decoded
    }

    func reset() { customThemes = [] }
}

// MARK: - Custom Agent Connection Models

struct CustomToolParameter: Identifiable, Codable {
    var id: UUID
    var name: String
    var type: String
    var paramDescription: String
    var required: Bool

    init(id: UUID = UUID(), name: String = "", type: String = "string",
         paramDescription: String = "", required: Bool = true) {
        self.id = id
        self.name = name
        self.type = type
        self.paramDescription = paramDescription
        self.required = required
    }
}

struct CustomAgentConnection: Identifiable, Codable {
    var id: UUID
    var name: String
    var toolDescription: String
    var apiEndpoint: String
    var parameters: [CustomToolParameter]
    var expectedOutput: String

    init(id: UUID = UUID(), name: String = "", toolDescription: String = "",
         apiEndpoint: String = "", parameters: [CustomToolParameter] = [],
         expectedOutput: String = "") {
        self.id = id
        self.name = name
        self.toolDescription = toolDescription
        self.apiEndpoint = apiEndpoint
        self.parameters = parameters
        self.expectedOutput = expectedOutput
    }

    var agentToolID: String { "custom_\(id.uuidString.prefix(8))" }

    func toAgentTool() -> AgentTool {
        let agentParams = parameters.map {
            AgentToolParameter(name: $0.name, type: $0.type,
                               description: $0.paramDescription, required: $0.required)
        }
        return AgentTool(
            id: agentToolID, displayName: name, description: toolDescription,
            parameters: agentParams, category: .utilities
        )
    }
}

// MARK: - Custom Tool Registry

final class CustomToolRegistry: ObservableObject {
    static let shared = CustomToolRegistry()

    @Published var connections: [CustomAgentConnection] = [] {
        didSet { save() }
    }

    private let defaultsKey = "customAgentConnections"

    private init() { load() }

    var asAgentTools: [AgentTool] { connections.map { $0.toAgentTool() } }

    private func save() {
        if let data = try? JSONEncoder().encode(connections) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([CustomAgentConnection].self, from: data) else { return }
        connections = decoded
    }

    func reset() { connections = [] }
}

// MARK: - GeneralSettingsView

struct GeneralSettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @StateObject private var apiKeyManager = APIKeyManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var toolRegistry = CustomToolRegistry.shared

    @State private var showAPIKeysSheet = false
    @State private var showThemeSheet = false
    @State private var showGitHubConfigSheet = false
    @State private var showAgentConnectionsSheet = false
    @State private var showCoreMLSheet = false
    @State private var showResetConfirmation = false

    // Quick Setup section state
    @State private var openRouterKey: String = ""
    @State private var githubToken: String = ""
    @State private var showOpenRouterKey = false
    @State private var showGitHubToken = false
    @State private var keySaved = false
    @State private var tokenSaved = false
    @State private var showExtensions = false

    var activeTheme: AppTheme {
        themeManager.theme(for: settings.selectedThemeID) ?? AppTheme.dark
    }

    var body: some View {
        NavigationStack {
            Form {
                quickSetupSection
                apiKeysSection
                editorSection
                dashboardSection
                themesSection
                gitHubSection
                agentConnectionsSection
                coreMLSection
                appManagementSection
                aboutSection
            }
            .onAppear {
                openRouterKey = KeychainService.shared.get(forKey: KeychainService.openRouterAPIKey) ?? ""
                githubToken = KeychainService.shared.get(forKey: KeychainService.githubToken) ?? ""
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showAPIKeysSheet) {
            APIKeysManagementView()
                .environmentObject(settings)
        }
        .sheet(isPresented: $showThemeSheet) {
            ThemeManagementView()
                .environmentObject(settings)
        }
        .sheet(isPresented: $showGitHubConfigSheet) {
            GitHubConfigView()
                .environmentObject(settings)
        }
        .sheet(isPresented: $showAgentConnectionsSheet) {
            AgentConnectionsView()
                .environmentObject(settings)
        }
        .sheet(isPresented: $showCoreMLSheet) {
            CoreMLSettingsView()
                .environmentObject(settings)
        }
        .sheet(isPresented: $showExtensions) {
            ExtensionsView()
        }
        .confirmationDialog(
            "Reset SwiftCode",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete All Data", role: .destructive) { resetApp() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all projects, settings, API keys, themes, agent connections, and cached files. This action cannot be undone.")
        }
    }

    // MARK: - Sections

    private var quickSetupSection: some View {
        Section {
            // OpenRouter API Key
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("OpenRouter API Key")
                        .font(.subheadline.weight(.medium))
                    if openRouterKey.isEmpty {
                        Text("Not configured").font(.caption).foregroundStyle(.red)
                    } else {
                        Text("Configured ✓").font(.caption).foregroundStyle(.green)
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
                TextField("sk-or-xxxxxxxxxxxx", text: $openRouterKey)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(.system(.body, design: .monospaced))
                Button {
                    KeychainService.shared.set(openRouterKey, forKey: KeychainService.openRouterAPIKey)
                    keySaved = true
                    showOpenRouterKey = false
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        keySaved = false
                    }
                } label: {
                    Label(keySaved ? "Saved!" : "Save Key",
                          systemImage: keySaved ? "checkmark.circle.fill" : "key.fill")
                        .foregroundStyle(keySaved ? .green : .orange)
                }
            }

            // GitHub Token
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("GitHub Token")
                        .font(.subheadline.weight(.medium))
                    if githubToken.isEmpty {
                        Text("Not configured").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Configured ✓").font(.caption).foregroundStyle(.green)
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
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        tokenSaved = false
                    }
                } label: {
                    Label(tokenSaved ? "Saved!" : "Save Token",
                          systemImage: tokenSaved ? "checkmark.circle.fill" : "key.fill")
                        .foregroundStyle(tokenSaved ? .green : .orange)
                }
            }

            // AI Model Picker
            Picker("AI Model", selection: $settings.selectedModel) {
                ForEach(OpenRouterModel.defaults) { model in
                    Text(model.name).tag(model.id)
                }
            }

            // Extensions shortcut
            Button {
                showExtensions = true
            } label: {
                Label("Manage Extensions", systemImage: "puzzlepiece.extension.fill")
                    .foregroundStyle(.orange)
            }
        } header: {
            Label("Quick Setup", systemImage: "bolt.fill")
        } footer: {
            Text("Configure your API keys and model directly here, or use the API Keys section for more advanced key management.")
        }
    }

    private var apiKeysSection: some View {
        Section {
            Button {
                showAPIKeysSheet = true
            } label: {
                HStack {
                    Label("Manage API Keys", systemImage: "key.fill")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(apiKeyManager.keys.count) key\(apiKeyManager.keys.count == 1 ? "" : "s")")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                        .font(.caption)
                }
            }
            if let defaultKey = apiKeyManager.keys.first(where: { $0.isDefault }) {
                HStack {
                    Text("Active Key")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Label(defaultKey.name, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }
        } header: {
            Label("API Keys", systemImage: "key.fill")
        } footer: {
            Text("Securely store multiple API keys. The default key is used automatically by AI services.")
        }
    }

    private var themesSection: some View {
        Section {
            Button {
                showThemeSheet = true
            } label: {
                HStack {
                    Label("Manage Themes", systemImage: "paintbrush.fill")
                        .foregroundStyle(.primary)
                    Spacer()
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: activeTheme.colors.background))
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(.secondary.opacity(0.3), lineWidth: 1))
                        Text(activeTheme.name)
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                        .font(.caption)
                }
            }
        } header: {
            Label("Themes", systemImage: "paintbrush.fill")
        } footer: {
            Text("Customize the visual appearance of the IDE. Create and save your own themes.")
        }
    }

    private var gitHubSection: some View {
        Section {
            Button {
                showGitHubConfigSheet = true
            } label: {
                HStack {
                    Label("GitHub & Git Configuration", systemImage: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.primary)
                    Spacer()
                    if !settings.gitUserName.isEmpty {
                        Text(settings.gitUserName)
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                        .font(.caption)
                }
            }
        } header: {
            Label("GitHub & Git", systemImage: "arrow.triangle.2.circlepath")
        } footer: {
            Text("Configure your GitHub token, Git identity, and default repository. These settings are shared across all projects.")
        }
    }

    private var editorSection: some View {
        Section {
            Toggle(isOn: $settings.alwaysPinFilesView) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Always Pin Files View")
                    Text("Keep the file navigator always visible in the code editor")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Label("Editor", systemImage: "pencil.and.outline")
        } footer: {
            Text("When enabled, the file navigator panel stays open by default whenever you open a project.")
        }
    }

    private var dashboardSection: some View {
        Section {
            // Layout picker
            Picker("Layout", selection: $settings.dashboardLayout) {
                ForEach(DashboardLayout.allCases, id: \.self) { layout in
                    Label(
                        layout.rawValue,
                        systemImage: layout == .grid ? "square.grid.2x2" : "list.bullet"
                    ).tag(layout)
                }
            }
            .pickerStyle(.segmented)

            // Sort order
            Picker("Sort By", selection: $settings.dashboardSortOrder) {
                ForEach(DashboardSortOrder.allCases, id: \.self) { order in
                    Text(order.rawValue).tag(order)
                }
            }

            Toggle(isOn: $settings.showProjectIcons) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show Project Icons")
                    Text("Display the Swift logo icon on each project card")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Toggle(isOn: $settings.showFileCount) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show File Count")
                    Text("Display the number of files on each project card")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Toggle(isOn: $settings.showLastOpenedTime) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show Last Opened Time")
                    Text("Display when each project was last opened")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Toggle(isOn: $settings.showFolderPreview) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show Folder Preview")
                    Text("Show the first file name as a preview in list layout")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Label("Dashboard", systemImage: "rectangle.grid.2x2")
        } footer: {
            Text("Customize how your projects appear on the Home screen. Switch between grid cards and a compact list view.")
        }
    }

    private var agentConnectionsSection: some View {
        Section {
            Button {
                showAgentConnectionsSheet = true
            } label: {
                HStack {
                    Label("Agent Tool Connections", systemImage: "puzzlepiece.extension.fill")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(toolRegistry.connections.count) tool\(toolRegistry.connections.count == 1 ? "" : "s")")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                        .font(.caption)
                }
            }
        } header: {
            Label("Agent Connections", systemImage: "puzzlepiece.extension.fill")
        } footer: {
            Text("Define custom tools the AI agent can call. Tools are registered immediately and available to the agent without app updates.")
        }
    }

    private var coreMLSection: some View {
        Section {
            Button {
                showCoreMLSheet = true
            } label: {
                HStack {
                    Label("CoreML Integration", systemImage: "brain.head.profile")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(settings.coreMLEnabled ? "Enabled" : "Disabled")
                        .foregroundStyle(settings.coreMLEnabled ? .green : .secondary)
                        .font(.caption)
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                        .font(.caption)
                }
            }
        } header: {
            Label("Local AI", systemImage: "brain.head.profile")
        } footer: {
            Text("Run AI models locally on device using CoreML for offline code completion and analysis.")
        }
    }

    private var appManagementSection: some View {
        Section {
            Button(role: .destructive) {
                showResetConfirmation = true
            } label: {
                Label("Reset SwiftCode", systemImage: "trash.fill")
            }
        } header: {
            Label("App Management", systemImage: "gear.badge")
        } footer: {
            Text("Removes all stored data and resets the app to its initial state.")
        }
    }

    private static let openRouterURL = URL(string: "https://openrouter.ai")!
    private static let githubAPIDocsURL = URL(string: "https://docs.github.com/en/rest")!

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0").foregroundStyle(.secondary)
            }
            HStack {
                Text("Build")
                Spacer()
                Text("1").foregroundStyle(.secondary)
            }
            Link(destination: Self.openRouterURL) {
                Label("OpenRouter API", systemImage: "link")
            }
            Link(destination: Self.githubAPIDocsURL) {
                Label("GitHub API Docs", systemImage: "link")
            }
        } header: {
            Label("About SwiftCode", systemImage: "info.circle")
        }
    }

    // MARK: - Reset

    private func resetApp() {
        // 1. Clear all API keys from keychain
        APIKeyManager.shared.reset()
        // 2. Clear custom themes
        ThemeManager.shared.reset()
        // 3. Clear custom agent tools
        CustomToolRegistry.shared.reset()
        // 4. Clear UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        // 5. Clear keychain tokens
        KeychainService.shared.delete(forKey: KeychainService.openRouterAPIKey)
        KeychainService.shared.delete(forKey: KeychainService.githubToken)
        // 6. Clear Documents directory
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        if let contents = try? FileManager.default.contentsOfDirectory(
            at: docs, includingPropertiesForKeys: nil
        ) {
            for url in contents {
                try? FileManager.default.removeItem(at: url)
            }
        }
        // 7. Clear active project state and reload
        ProjectManager.shared.activeProject = nil
        ProjectManager.shared.activeFileNode = nil
        ProjectManager.shared.activeFileContent = ""
        ProjectManager.shared.loadProjects()
        dismiss()
    }
}

// MARK: - API Keys Management View

struct APIKeysManagementView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = APIKeyManager.shared

    @State private var showAddSheet = false
    @State private var editingEntry: APIKeyEntry?
    @State private var showDeleteConfirmation = false
    @State private var entryToDelete: APIKeyEntry?

    var body: some View {
        NavigationStack {
            List {
                if manager.keys.isEmpty {
                    ContentUnavailableView(
                        "No API Keys",
                        systemImage: "key.fill",
                        description: Text("Add API keys to use with OpenRouter, GitHub, or custom services.")
                    )
                } else {
                    ForEach(manager.keys) { entry in
                        APIKeyRowView(entry: entry)
                            .contentShape(Rectangle())
                            .onTapGesture { editingEntry = entry }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    entryToDelete = entry
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                if !entry.isDefault {
                                    Button {
                                        manager.setDefault(entry)
                                    } label: {
                                        Label("Set Default", systemImage: "checkmark.circle.fill")
                                    }
                                    .tint(.green)
                                }
                            }
                    }
                }
            }
            .navigationTitle("API Keys")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddEditAPIKeyView(entry: nil)
            }
            .sheet(item: $editingEntry) { entry in
                AddEditAPIKeyView(entry: entry)
            }
            .confirmationDialog(
                "Delete API Key",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let entry = entryToDelete { manager.delete(entry) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let name = entryToDelete?.name {
                    Text("Delete \(name)? This cannot be undone.")
                }
            }
        }
    }
}

struct APIKeyRowView: View {
    let entry: APIKeyEntry
    @StateObject private var manager = APIKeyManager.shared

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.provider.icon)
                .foregroundStyle(entry.provider.tintColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.name)
                        .font(.headline)
                    if entry.isDefault {
                        Text("DEFAULT")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.green.opacity(0.15), in: Capsule())
                            .foregroundStyle(.green)
                    }
                }
                Text(entry.provider.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if manager.keyValue(for: entry)?.isEmpty == false {
                    Text("Key configured")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Add / Edit API Key View

struct AddEditAPIKeyView: View {
    let entry: APIKeyEntry?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = APIKeyManager.shared

    @State private var name: String
    @State private var provider: APIKeyProvider
    @State private var keyValue: String
    @State private var showKey = false
    @State private var saved = false

    init(entry: APIKeyEntry?) {
        self.entry = entry
        _name = State(initialValue: entry?.name ?? "")
        _provider = State(initialValue: entry?.provider ?? .openRouter)
        _keyValue = State(initialValue: "")
    }

    var isEditing: Bool { entry != nil }
    var isValid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !keyValue.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Key Details") {
                    TextField("Key Name (e.g. My OpenRouter Key)", text: $name)
                        .autocorrectionDisabled()

                    Picker("Provider", selection: $provider) {
                        ForEach(APIKeyProvider.allCases, id: \.self) { p in
                            Label(p.rawValue, systemImage: p.icon).tag(p)
                        }
                    }
                }

                Section {
                    HStack {
                        Group {
                            if showKey {
                                TextField("Enter API key", text: $keyValue)
                            } else {
                                SecureField("Enter API key", text: $keyValue)
                            }
                        }
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .fontDesign(.monospaced)

                        Button {
                            showKey.toggle()
                        } label: {
                            Image(systemName: showKey ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Key Value")
                } footer: {
                    Text("Keys are stored securely in the iOS Keychain.")
                }
            }
            .navigationTitle(isEditing ? "Edit Key" : "Add API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Update" : "Add") { saveKey() }
                        .disabled(!isValid)
                }
            }
            .onAppear {
                if let entry {
                    keyValue = manager.keyValue(for: entry) ?? ""
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func saveKey() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if isEditing, let existing = entry {
            var updated = existing
            updated.name = trimmedName
            updated.provider = provider
            if let idx = manager.keys.firstIndex(where: { $0.id == existing.id }) {
                manager.keys[idx] = updated
            }
            manager.update(updated, keyValue: keyValue)
        } else {
            manager.add(name: trimmedName, provider: provider, keyValue: keyValue)
        }
        dismiss()
    }
}

// MARK: - Theme Management View

struct ThemeManagementView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager.shared

    @State private var showCreateSheet = false
    @State private var editingTheme: AppTheme?

    var body: some View {
        NavigationStack {
            List {
                Section("Built-in Themes") {
                    ForEach(AppTheme.builtIns) { theme in
                        ThemeRowView(theme: theme, isSelected: settings.selectedThemeID == theme.id)
                            .contentShape(Rectangle())
                            .onTapGesture { settings.selectedThemeID = theme.id }
                    }
                }

                if !themeManager.customThemes.isEmpty {
                    Section("Custom Themes") {
                        ForEach(themeManager.customThemes) { theme in
                            ThemeRowView(theme: theme, isSelected: settings.selectedThemeID == theme.id)
                                .contentShape(Rectangle())
                                .onTapGesture { settings.selectedThemeID = theme.id }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        if settings.selectedThemeID == theme.id {
                                            settings.selectedThemeID = "dark"
                                        }
                                        themeManager.delete(theme)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        editingTheme = theme
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                        }
                    }
                }
            }
            .navigationTitle("Themes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Label("New Theme", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                CustomThemeEditorView(theme: nil)
                    .environmentObject(settings)
            }
            .sheet(item: $editingTheme) { theme in
                CustomThemeEditorView(theme: theme)
                    .environmentObject(settings)
            }
        }
    }
}

struct ThemeRowView: View {
    let theme: AppTheme
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Color swatch
            HStack(spacing: 3) {
                ForEach([
                    theme.colors.background,
                    theme.colors.syntaxKeyword,
                    theme.colors.accent,
                    theme.colors.syntaxString
                ], id: \.self) { hex in
                    Rectangle()
                        .fill(Color(hex: hex))
                        .frame(width: 16, height: 32)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(.secondary.opacity(0.2)))

            VStack(alignment: .leading, spacing: 2) {
                Text(theme.name)
                    .font(.headline)
                Text(theme.isBuiltIn ? "Built-in" : "Custom")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Custom Theme Editor View

struct CustomThemeEditorView: View {
    let theme: AppTheme?
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager.shared

    @State private var themeName: String
    @State private var backgroundColor: Color
    @State private var editorTextColor: Color
    @State private var syntaxKeywordColor: Color
    @State private var syntaxStringColor: Color
    @State private var syntaxCommentColor: Color
    @State private var syntaxTypeColor: Color
    @State private var accentColor: Color
    @State private var toolbarColor: Color
    @State private var panelBackgroundColor: Color

    var isEditing: Bool { theme != nil }

    init(theme: AppTheme?) {
        self.theme = theme
        let t = theme ?? AppTheme.dark
        _themeName = State(initialValue: theme?.name ?? "My Theme")
        _backgroundColor = State(initialValue: Color(hex: t.colors.background))
        _editorTextColor = State(initialValue: Color(hex: t.colors.editorText))
        _syntaxKeywordColor = State(initialValue: Color(hex: t.colors.syntaxKeyword))
        _syntaxStringColor = State(initialValue: Color(hex: t.colors.syntaxString))
        _syntaxCommentColor = State(initialValue: Color(hex: t.colors.syntaxComment))
        _syntaxTypeColor = State(initialValue: Color(hex: t.colors.syntaxType))
        _accentColor = State(initialValue: Color(hex: t.colors.accent))
        _toolbarColor = State(initialValue: Color(hex: t.colors.toolbar))
        _panelBackgroundColor = State(initialValue: Color(hex: t.colors.panelBackground))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Theme Name") {
                    TextField("Theme Name", text: $themeName)
                        .autocorrectionDisabled()
                }

                Section("Editor Colors") {
                    ColorPicker("Background", selection: $backgroundColor, supportsOpacity: false)
                    ColorPicker("Editor Text", selection: $editorTextColor, supportsOpacity: false)
                    ColorPicker("Accent", selection: $accentColor, supportsOpacity: false)
                }

                Section("Syntax Highlighting") {
                    ColorPicker("Keywords", selection: $syntaxKeywordColor, supportsOpacity: false)
                    ColorPicker("Strings", selection: $syntaxStringColor, supportsOpacity: false)
                    ColorPicker("Comments", selection: $syntaxCommentColor, supportsOpacity: false)
                    ColorPicker("Types", selection: $syntaxTypeColor, supportsOpacity: false)
                }

                Section("UI Colors") {
                    ColorPicker("Toolbar", selection: $toolbarColor, supportsOpacity: false)
                    ColorPicker("Panel Background", selection: $panelBackgroundColor, supportsOpacity: false)
                }

                Section("Preview") {
                    themePreview
                }
            }
            .navigationTitle(isEditing ? "Edit Theme" : "New Theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Update" : "Create") { saveTheme() }
                        .disabled(themeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var themePreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("// Preview")
                .foregroundStyle(syntaxCommentColor)
            HStack(spacing: 0) {
                Text("struct ").foregroundStyle(syntaxKeywordColor)
                Text("MyView").foregroundStyle(syntaxTypeColor)
                Text(": View {").foregroundStyle(editorTextColor)
            }
            HStack(spacing: 0) {
                Text("    let title = ").foregroundStyle(editorTextColor)
                Text("\"Hello\"").foregroundStyle(syntaxStringColor)
            }
        }
        .font(.system(.caption, design: .monospaced))
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func saveTheme() {
        let colors = ThemeColors(
            background: backgroundColor.toHex(),
            editorText: editorTextColor.toHex(),
            syntaxKeyword: syntaxKeywordColor.toHex(),
            syntaxString: syntaxStringColor.toHex(),
            syntaxComment: syntaxCommentColor.toHex(),
            syntaxType: syntaxTypeColor.toHex(),
            accent: accentColor.toHex(),
            toolbar: toolbarColor.toHex(),
            panelBackground: panelBackgroundColor.toHex()
        )
        if isEditing, let existing = theme {
            let updated = AppTheme(
                id: existing.id,
                name: themeName.trimmingCharacters(in: .whitespacesAndNewlines),
                isBuiltIn: false,
                colors: colors
            )
            themeManager.update(updated)
        } else {
            let newTheme = AppTheme(
                id: UUID().uuidString,
                name: themeName.trimmingCharacters(in: .whitespacesAndNewlines),
                isBuiltIn: false,
                colors: colors
            )
            themeManager.add(newTheme)
            settings.selectedThemeID = newTheme.id
        }
        dismiss()
    }
}

// MARK: - GitHub Configuration View

struct GitHubConfigView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    private static let savedIndicatorDuration: TimeInterval = 2.0

    @State private var githubToken: String = ""
    @State private var showToken = false
    @State private var tokenSaved = false
    @State private var showAddRepoSheet = false
    @State private var newRepoName = ""
    @State private var newRepoOwner = ""
    @State private var newRepoURL = ""
    @State private var newRepoBranch = "main"

    @StateObject private var permManager = RepoPermManager.shared

    var body: some View {
        NavigationStack {
            Form {
                // GitHub Authentication
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Personal Access Token")
                                .font(.headline)
                            if githubToken.isEmpty {
                                Text("Not Set")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            } else {
                                Text("Token configured")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }
                        Spacer()
                        Button {
                            showToken.toggle()
                        } label: {
                            Image(systemName: showToken ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    if showToken {
                        TextField("ghp_xxxxxxxxxxxx", text: $githubToken)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .fontDesign(.monospaced)

                        Button {
                            KeychainService.shared.set(githubToken, forKey: KeychainService.githubToken)
                            tokenSaved = true
                            showToken = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + Self.savedIndicatorDuration) { tokenSaved = false }
                        } label: {
                            Label(tokenSaved ? "Saved!" : "Save Token",
                                  systemImage: tokenSaved ? "checkmark.circle.fill" : "key.fill")
                                .foregroundStyle(tokenSaved ? .green : .blue)
                        }
                    }
                } header: {
                    Label("GitHub Account", systemImage: "chevron.left.forwardslash.chevron.right")
                } footer: {
                    Text("Your token is stored securely in the iOS Keychain. Create a token at github.com/settings/tokens with repo and workflow scopes.")
                }

                // Git Identity
                Section {
                    TextField("Name (e.g. Jane Doe)", text: $settings.gitUserName)
                        .autocorrectionDisabled()
                    TextField("Email (e.g. jane@example.com)", text: $settings.gitUserEmail)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                } header: {
                    Label("Git Identity", systemImage: "person.fill")
                } footer: {
                    Text("Used in commit messages across all repositories.")
                }

                // Repository Defaults
                Section {
                    TextField("Owner/Repo (e.g. apple/swift)", text: $settings.defaultGitHubRepo)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    TextField("Default Branch (e.g. main)", text: $settings.defaultBranch)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Label("Repository Defaults", systemImage: "folder.fill")
                } footer: {
                    Text("These defaults are used when creating new projects or cloning repositories.")
                }

                // Saved Repositories
                Section {
                    if settings.savedRepositories.isEmpty {
                        Text("No saved repositories")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    } else {
                        ForEach(settings.savedRepositories) { repo in
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(repo.name)
                                        .font(.headline)
                                    Text("\(repo.owner)/\(repo.name)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(repo.defaultBranch)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                Spacer()
                                if settings.defaultRepositoryID == repo.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                settings.setDefaultRepository(repo)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    settings.removeRepository(repo)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    }

                    Button {
                        showAddRepoSheet = true
                    } label: {
                        Label("Add Repository", systemImage: "plus.circle")
                    }

                    Toggle("Start On New Project", isOn: $settings.startOnNewProject)
                } header: {
                    Label("Saved Repositories", systemImage: "bookmark.fill")
                } footer: {
                    Text("Saved repositories can be used to quickly initialize new projects. When 'Start On New Project' is enabled, the default repository will be used to initialize new projects.")
                }

                // SSH & HTTPS Authentication
                Section {
                    TextField("SSH Key Path", text: $settings.sshKeyPath)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    TextField("HTTPS Auth Token", text: $settings.httpsAuthToken)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Label("Authentication", systemImage: "lock.shield.fill")
                } footer: {
                    Text("Configure SSH key path or HTTPS authentication token for Git operations.")
                }

                // Advanced Git Options
                Section {
                    Toggle("Auto Fetch Repositories", isOn: $settings.autoFetchRepositories)
                    Toggle("Auto Pull Before Commit", isOn: $settings.autoPullBeforeCommit)
                    Toggle("Workflow Monitoring", isOn: $settings.workflowMonitoringEnabled)
                } header: {
                    Label("Git Automation", systemImage: "gearshape.2.fill")
                } footer: {
                    Text("Automatic fetch keeps your local copy in sync. Auto pull before commit prevents merge conflicts.")
                }

                // Commit Message Template
                Section {
                    TextField("e.g. [Feature] {message}", text: $settings.commitMessageTemplate)
                        .autocorrectionDisabled()
                } header: {
                    Label("Commit Template", systemImage: "text.badge.checkmark")
                } footer: {
                    Text("Define a template for commit messages. Use {message} as a placeholder for the actual message.")
                }

                // Repository Permissions
                Section {
                    if permManager.isLoading {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Checking permissions…")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    } else if permManager.hasChecked {
                        if let error = permManager.errorMessage {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .font(.caption)
                        } else if permManager.permissions.isEmpty {
                            Text("No scopes detected. Your token may have no listed scopes or uses fine-grained permissions.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(permManager.permissions) { perm in
                                HStack(spacing: 12) {
                                    Image(systemName: perm.icon)
                                        .foregroundStyle(.blue)
                                        .frame(width: 22)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(perm.scope)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.primary)
                                            .fontDesign(.monospaced)
                                        Text(perm.humanReadable)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        Button {
                            Task { await permManager.fetchPermissions() }
                        } label: {
                            Label("Re-check Permissions", systemImage: "arrow.clockwise")
                                .font(.callout)
                        }
                    } else {
                        Button {
                            Task { await permManager.fetchPermissions() }
                        } label: {
                            Label("Check Permissions", systemImage: "checkmark.shield.fill")
                                .foregroundStyle(.blue)
                        }
                        Text("Tap to inspect what scopes your current GitHub token has.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                } header: {
                    Label("Repository Permissions", systemImage: "lock.open.fill")
                } footer: {
                    Text("Permissions are determined by your GitHub token's OAuth scopes.")
                }
            }
            .navigationTitle("GitHub & Git Config")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                githubToken = KeychainService.shared.get(forKey: KeychainService.githubToken) ?? ""
            }
            .sheet(isPresented: $showAddRepoSheet) {
                addRepositorySheet
            }
        }
    }

    private var addRepositorySheet: some View {
        NavigationStack {
            Form {
                Section("Repository Details") {
                    TextField("Repository Name", text: $newRepoName)
                        .autocorrectionDisabled()
                    TextField("Owner", text: $newRepoOwner)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    TextField("URL (e.g. https://github.com/owner/repo)", text: $newRepoURL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    TextField("Default Branch", text: $newRepoBranch)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("Add Repository")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        clearRepoForm()
                        showAddRepoSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let repo = SavedRepository(
                            name: newRepoName.trimmingCharacters(in: .whitespacesAndNewlines),
                            owner: newRepoOwner.trimmingCharacters(in: .whitespacesAndNewlines),
                            repositoryURL: newRepoURL.trimmingCharacters(in: .whitespacesAndNewlines),
                            defaultBranch: newRepoBranch.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        settings.addRepository(repo)
                        clearRepoForm()
                        showAddRepoSheet = false
                    }
                    .disabled(newRepoName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              newRepoOwner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func clearRepoForm() {
        newRepoName = ""
        newRepoOwner = ""
        newRepoURL = ""
        newRepoBranch = "main"
    }
}

// MARK: - Agent Connections View

struct AgentConnectionsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @StateObject private var registry = CustomToolRegistry.shared

    @State private var showAddSheet = false
    @State private var editingConnection: CustomAgentConnection?

    var body: some View {
        NavigationStack {
            List {
                if registry.connections.isEmpty {
                    ContentUnavailableView(
                        "No Custom Tools",
                        systemImage: "puzzlepiece.extension",
                        description: Text("Add custom tools to extend the AI agent's capabilities.")
                    )
                } else {
                    ForEach(registry.connections) { connection in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(connection.name)
                                    .font(.headline)
                                Spacer()
                                Text("ID: \(connection.agentToolID)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .fontDesign(.monospaced)
                            }
                            Text(connection.toolDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                            if !connection.apiEndpoint.isEmpty {
                                Text(connection.apiEndpoint)
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                                    .lineLimit(1)
                            }
                            if !connection.parameters.isEmpty {
                                Text("\(connection.parameters.count) parameter\(connection.parameters.count == 1 ? "" : "s")")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                        .onTapGesture { editingConnection = connection }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                registry.connections.removeAll { $0.id == connection.id }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Agent Connections")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                CustomToolEditorView(connection: nil)
            }
            .sheet(item: $editingConnection) { connection in
                CustomToolEditorView(connection: connection)
            }
        }
    }
}

// MARK: - Custom Tool Editor View

struct CustomToolEditorView: View {
    let connection: CustomAgentConnection?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var registry = CustomToolRegistry.shared

    @State private var name: String
    @State private var toolDescription: String
    @State private var apiEndpoint: String
    @State private var expectedOutput: String
    @State private var parameters: [CustomToolParameter]
    @State private var showAddParameter = false
    @State private var showAdvancedBuilder = false

    var isEditing: Bool { connection != nil }
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !toolDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(connection: CustomAgentConnection?) {
        self.connection = connection
        _name = State(initialValue: connection?.name ?? "")
        _toolDescription = State(initialValue: connection?.toolDescription ?? "")
        _apiEndpoint = State(initialValue: connection?.apiEndpoint ?? "")
        _expectedOutput = State(initialValue: connection?.expectedOutput ?? "")
        _parameters = State(initialValue: connection?.parameters ?? [])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tool Info") {
                    TextField("Tool Name", text: $name)
                        .autocorrectionDisabled()
                    TextField("Description", text: $toolDescription, axis: .vertical)
                        .lineLimit(3)
                }

                Section {
                    TextField("API Endpoint URL", text: $apiEndpoint)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    TextField("Expected Output Description", text: $expectedOutput, axis: .vertical)
                        .lineLimit(2)
                } header: {
                    Text("Endpoint")
                } footer: {
                    Text("The agent will send JSON POST requests to this URL with the parameters as the request body.")
                }

                Section {
                    ForEach($parameters) { $param in
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Parameter Name", text: $param.name)
                                .autocorrectionDisabled()
                                .font(.headline)
                            TextField("Description", text: $param.paramDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack {
                                Picker("Type", selection: $param.type) {
                                    Text("string").tag("string")
                                    Text("number").tag("number")
                                    Text("boolean").tag("boolean")
                                }
                                .pickerStyle(.segmented)
                                Toggle("Required", isOn: $param.required)
                                    .labelsHidden()
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { offsets in parameters.remove(atOffsets: offsets) }

                    Button {
                        parameters.append(CustomToolParameter())
                    } label: {
                        Label("Add Parameter", systemImage: "plus.circle.fill")
                    }
                } header: {
                    HStack {
                        Text("Parameters")
                        Spacer()
                        if !parameters.isEmpty {
                            EditButton()
                                .font(.caption)
                        }
                    }
                }

                if !isEditing {
                    Section {
                        Button {
                            showAdvancedBuilder = true
                        } label: {
                            Label("Build Tool from Scratch", systemImage: "wrench.and.screwdriver.fill")
                                .foregroundStyle(.orange)
                        }
                    } header: {
                        Text("Advanced")
                    } footer: {
                        Text("Build a fully custom tool with HTTP configuration, headers, body templates, and parameter definitions.")
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Tool" : "New Tool")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Update" : "Add") { saveTool() }
                        .disabled(!isValid)
                }
            }
            .sheet(isPresented: $showAdvancedBuilder) {
                CustomToolBuilderView()
            }
        }
    }

    private func saveTool() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDesc = toolDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if isEditing, let existing = connection {
            var updated = existing
            updated.name = trimmedName
            updated.toolDescription = trimmedDesc
            updated.apiEndpoint = apiEndpoint
            updated.expectedOutput = expectedOutput
            updated.parameters = parameters
            if let idx = registry.connections.firstIndex(where: { $0.id == existing.id }) {
                registry.connections[idx] = updated
            }
        } else {
            let newConn = CustomAgentConnection(
                name: trimmedName,
                toolDescription: trimmedDesc,
                apiEndpoint: apiEndpoint,
                parameters: parameters,
                expectedOutput: expectedOutput
            )
            registry.connections.append(newConn)
        }
        dismiss()
    }
}

// MARK: - CoreML Settings View

struct CoreMLSettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @StateObject private var codingManager = CodingManager.shared

    @State private var importedModels: [URL] = []
    @State private var showModelImporter = false
    @State private var modelToDelete: URL?
    @State private var showDeleteConfirmation = false
    @State private var importError: String?
    @State private var showImportError = false
    @State private var deleteError: String?
    @State private var showDeleteError = false

    private static let coreMLExtensions: Set<String> = ["mlmodel", "mlmodelc", "mlpackage"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Enable Local Inference", isOn: $settings.coreMLEnabled)
                    if settings.coreMLEnabled {
                        Toggle("Hybrid Mode (CoreML + API)", isOn: $settings.coreMLHybridMode)
                    }
                } header: {
                    Label("CoreML", systemImage: "brain.head.profile")
                } footer: {
                    Text("When enabled, the agent uses an on-device CoreML model for code completion, analysis, and offline assistance.")
                }

                if settings.coreMLEnabled {
                    Section {
                        if importedModels.isEmpty {
                            Text("No models imported")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(importedModels, id: \.lastPathComponent) { model in
                                HStack {
                                    Image(systemName: "cube.fill")
                                        .foregroundStyle(.purple)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(model.lastPathComponent)
                                            .font(.headline)
                                        Text(model.pathExtension.uppercased())
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if settings.coreMLSelectedModel == model.lastPathComponent {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    settings.coreMLSelectedModel = model.lastPathComponent
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        modelToDelete = model
                                        showDeleteConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }

                        Button {
                            showModelImporter = true
                        } label: {
                            Label("Import .mlmodel", systemImage: "square.and.arrow.down")
                        }
                    } header: {
                        Label("Imported Models", systemImage: "cube.fill")
                    } footer: {
                        Text("Models are stored in Documents/Models and are accessible from the Files app.")
                    }

                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Usage Limit")
                                Spacer()
                                Text("\(Int(settings.coreMLUsageLimit)) requests/session")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                            Slider(value: $settings.coreMLUsageLimit, in: 10...500, step: 10)
                                .tint(.purple)
                        }

                        if !settings.coreMLSelectedModel.isEmpty {
                            HStack {
                                Text("Active Model")
                                Spacer()
                                Text(settings.coreMLSelectedModel)
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                        }
                    } header: {
                        Label("Configuration", systemImage: "slider.horizontal.3")
                    }

                    Section {
                        Label("Local Code Completion", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Label("Code Analysis", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Label("Syntax Prediction", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Label("Project Summarization", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Label("Offline AI Assistance", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } header: {
                        Label("Supported Use Cases", systemImage: "list.bullet")
                    } footer: {
                        Text("These use cases are available when a compatible CoreML model is imported and local inference is enabled.")
                    }
                }
            }
            .navigationTitle("CoreML Integration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                importedModels = codingManager.listModels()
            }
            .fileImporter(
                isPresented: $showModelImporter,
                allowedContentTypes: [.item],
                allowsMultipleSelection: false
            ) { result in
                do {
                    guard let url = try result.get().first else { return }
                    let ext = url.pathExtension.lowercased()
                    guard Self.coreMLExtensions.contains(ext) else {
                        importError = "Only .mlmodel, .mlmodelc, and .mlpackage files are supported."
                        showImportError = true
                        return
                    }
                    let accessing = url.startAccessingSecurityScopedResource()
                    defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                    let imported = try codingManager.importModel(from: url)
                    importedModels = codingManager.listModels()
                    if settings.coreMLSelectedModel.isEmpty {
                        settings.coreMLSelectedModel = imported.lastPathComponent
                    }
                } catch {
                    importError = error.localizedDescription
                    showImportError = true
                }
            }
            .alert("Import Failed", isPresented: $showImportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importError ?? "An unknown error occurred.")
            }
            .confirmationDialog(
                "Delete Model",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let model = modelToDelete {
                        do {
                            try codingManager.deleteModel(named: model.lastPathComponent)
                            if settings.coreMLSelectedModel == model.lastPathComponent {
                                settings.coreMLSelectedModel = ""
                            }
                            importedModels = codingManager.listModels()
                        } catch {
                            deleteError = error.localizedDescription
                            showDeleteError = true
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let name = modelToDelete?.lastPathComponent {
                    Text("Delete \(name)? This cannot be undone.")
                }
            }
            .alert("Delete Failed", isPresented: $showDeleteError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deleteError ?? "An unknown error occurred.")
            }
        }
    }
}
