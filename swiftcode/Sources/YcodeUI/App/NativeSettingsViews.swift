import YcodeAssistant
import SwiftCodeCloud
import SwiftCodeConnect
import YcodeIDECore
import SwiftUI
import AppKit

public enum SettingsCategory: String, CaseIterable, Identifiable, Sendable {
    case general = "general"
    case themes = "themes"
    case sourceControl = "source_control"
    case cloud = "cloud"
    case backups = "backups"
    case connect = "connect_host"
    case assist = "ai_assist"
    case composio = "composio"
    case offlineModels = "offline_models"
    case plugins = "plugins"
    case updates = "updates"
    case credits = "credits"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .general: return "General"
        case .themes: return "Themes & Appearance"
        case .sourceControl: return "Source Control"
        case .cloud: return "Cloud"
        case .backups: return "Backups"
        case .connect: return "Connect"
        case .assist: return "AI & Assist"
        case .composio: return "Composio"
        case .offlineModels: return "Offline Models"
        case .plugins: return "Plugins"
        case .updates: return "Updates"
        case .credits: return "Credits"
        }
    }

    public var icon: String {
        switch self {
        case .general: return "gearshape"
        case .themes: return "paintbrush"
        case .sourceControl: return "arrow.triangle.branch"
        case .cloud: return "icloud"
        case .backups: return "clock.arrow.circlepath"
        case .connect: return "iphone.radiowaves.left.and.right"
        case .assist: return "sparkles"
        case .composio: return "link.badge.plus"
        case .offlineModels: return "externaldrive"
        case .plugins: return "cpu"
        case .updates: return "arrow.triangle.2.circlepath.circle"
        case .credits: return "person.2"
        }
    }
}

public enum NativeSettingsLayout {
    public static let width: CGFloat = 940
    public static let height: CGFloat = 640
}

@Observable
@MainActor
public final class NativeSettingsState {
    public static let shared = NativeSettingsState()
    public var selectedCategory: SettingsCategory = .general
}

public struct NativeSettingsContainerView: View {
    @Bindable var state: NativeSettingsState = .shared
    @Environment(AppSettings.self) private var settings

    public init(state: NativeSettingsState = .shared) {
        self.state = state
    }

    public init(selectedCategory: SettingsCategory) {
        self.state = .shared
        self.state.selectedCategory = selectedCategory
    }

    public var body: some View {
        VStack(spacing: 0) {
            SettingsCategoryTabBar(selected: $state.selectedCategory)
                .padding(.top, 10)
                .padding(.bottom, 6)
                .background(Color(nsColor: .windowBackgroundColor))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(Color(nsColor: .separatorColor)),
                    alignment: .bottom
                )

            HStack(spacing: 10) {
                Image(systemName: state.selectedCategory.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.accentColor)

                Text(state.selectedCategory.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(Color(nsColor: .separatorColor)),
                alignment: .bottom
            )

            Group {
                switch state.selectedCategory {
                case .general:
                    NativeGeneralSettingsView()
                case .themes:
                    NativeThemesSettingsView()
                case .sourceControl:
                    NativeSourceControlSettingsView()
                case .cloud:
                    NativeCloudSettingsView()
                case .backups:
                    NativeBackupsSettingsView()
                case .connect:
                    NativeConnectSettingsView()
                case .assist:
                    NativeAssistSettingsView()
                case .composio:
                    NativeComposioSettingsView()
                case .offlineModels:
                    NativeOfflineModelsSettingsView()
                case .plugins:
                    NativePluginsSettingsView()
                case .updates:
                    NativeUpdatesSettingsView()
                case .credits:
                    NativeCreditsSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .frame(minWidth: 880, maxWidth: .infinity, minHeight: 480, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipped()
        .environment(settings)
    }
}

public struct SettingsCategoryTabBar: View {
    @Binding var selected: SettingsCategory

    public init(selected: Binding<SettingsCategory>) {
        self._selected = selected
    }

    public var body: some View {
        HStack(spacing: 2) {
            Spacer(minLength: 0)
            ForEach(SettingsCategory.allCases) { category in
                Button {
                    selected = category
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: category.icon)
                            .font(.system(size: 15, weight: .semibold))
                        Text(category.title)
                            .font(.system(size: 10, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .foregroundStyle(selected == category ? Color.accentColor : .secondary)
                    .frame(width: 78, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(selected == category ? Color.accentColor.opacity(0.14) : Color.clear)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .help(category.title)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
    }
}

public struct NativeGeneralSettingsView: View {
    @Environment(AppSettings.self) private var settings

    public init() {}

    public var body: some View {
        @Bindable var settings = settings
        Form {
            Section("Settings Experience") {
                Toggle("Use New Settings Window", isOn: $settings.useNewSettingsWindow)
                Text("When enabled, preferences will open in the modern native macOS settings window with toolbar tabs. Disable to use the legacy multi-panel window.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Welcome Style Interface") {
                Picker("Interface Style", selection: $settings.welcomeStyleInterface) {
                    ForEach(WelcomeStyleInterface.allCases, id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                Text("Style 27 is the standard vertical launcher. Style 26 provides the classic two-pane project selector.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Editor Defaults") {
                Stepper(value: $settings.editorFontSize, in: 9...36, step: 1) {
                    HStack {
                        Text("Editor Font Size")
                        Spacer()
                        Text("\(Int(settings.editorFontSize)) pt")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }

                Toggle("Auto-Save", isOn: $settings.autoSave)
                Text("Automatically save open documents as edits are performed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Start on New Project", isOn: $settings.startOnNewProject)
                Text("Display the new project template wizard when SwiftCode launches.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Organization & Templates") {
                TextField("Default Organization", text: $settings.defaultOrganization)
                Text("Organization identifier used for bundle identifiers in generated projects (e.g. com.example).")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("Author Name", text: $settings.fileHeaderAuthor)
                Text("Name placed in generated file header comments.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("Custom Comment", text: $settings.fileHeaderCustomComment)
                Text("Custom text or copyright notice appended to generated file headers.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Project Location") {
                Toggle("Save Projects to Custom Folder", isOn: $settings.saveProjectsOnCustomFolder)

                HStack(spacing: 8) {
                    TextField("Folder Path", text: $settings.customProjectsFolder)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!settings.saveProjectsOnCustomFolder)

                    Button("Choose...") {
                        selectCustomFolder()
                    }
                    .disabled(!settings.saveProjectsOnCustomFolder)
                }
            }
        }
        .formStyle(.grouped)
        .clipped()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func selectCustomFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let selectedURL = panel.url {
            settings.customProjectsFolder = selectedURL.path
        }
    }
}

public struct NativeThemesSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @State private var themeManager = ThemeManager.shared
    @State private var prefs = Preferences.shared
    @State private var customBgColor: Color = .black

    private let availableFonts = [
        "SF Mono", "Menlo", "Monaco", "Fira Code", "JetBrains Mono", "Courier New", "System Monospaced"
    ]

    public init() {}

    public var body: some View {
        @Bindable var settings = settings
        Form {
            Section("Theme") {
                Toggle("Use Dark Appearance", isOn: $settings.useDarkTheme)

                Picker("Editor Syntax Theme", selection: $settings.selectedThemeID) {
                    ForEach(themeManager.allThemes) { theme in
                        HStack {
                            Text(theme.name)
                            if theme.isBuiltIn {
                                Text("(Preset)").foregroundStyle(.secondary)
                            }
                        }
                        .tag(theme.id)
                    }
                }
            }

            Section("Custom Colors") {
                ColorPicker("Custom Background Color", selection: $customBgColor)
                    .onChange(of: customBgColor) { _, newColor in
                        if let nsColor = NSColor(newColor).usingColorSpace(.sRGB) {
                            prefs.customBackgroundColor = String(format: "#%02X%02X%02X", Int(nsColor.redComponent * 255), Int(nsColor.greenComponent * 255), Int(nsColor.blueComponent * 255))
                        }
                    }

                if !prefs.customBackgroundColor.isEmpty {
                    HStack {
                        Button("Reset Custom Background") {
                            prefs.customBackgroundColor = ""
                            if let bg = EditorTheme.color(prefs.customBackgroundColor) { customBgColor = Color(nsColor: bg) }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        Text("Empty value falls back to the theme color.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("SwiftCode Accent Color") {
                AccentColorSettingsRow()
                Text("The accent color tints buttons, selections, and highlights across SwiftCode.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Typography & Spacing") {
                Picker("Editor Font", selection: Binding(
                    get: { prefs.editorFontName.isEmpty ? "(Theme default)" : prefs.editorFontName },
                    set: { prefs.editorFontName = $0 == "(Theme default)" ? "" : $0 }
                )) {
                    Text("(Theme default)").tag("(Theme default)")
                    ForEach(availableFonts, id: \.self) { font in
                        Text(font).tag(font)
                    }
                }

                TextField("Custom Font Family (overrides picker)", text: Binding(
                    get: { prefs.editorFontName },
                    set: { prefs.editorFontName = $0 }
                ))
                Text("Leave empty to use the selected theme's font. Any installed font family name works.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Stepper(value: Binding(
                    get: { prefs.editorFontSize },
                    set: { prefs.editorFontSize = $0; settings.editorFontSize = $0 }
                ), in: 10...28, step: 1) {
                    HStack {
                        Text("Font Size")
                        Spacer()
                        Text("\(Int(prefs.editorFontSize)) pt")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }

                HStack {
                    Text("Line Height Factor")
                    Spacer()
                    Slider(value: Binding(
                        get: { prefs.lineSpacingFactor },
                        set: { prefs.lineSpacingFactor = $0 }
                    ), in: 1.0...2.0, step: 0.1) {
                        Text("Line Spacing")
                    }
                    .frame(width: 140)
                    Text(String(format: "%.1fx", prefs.lineSpacingFactor))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                }
            }

            Section("Cursor & Editor Display") {
                Picker("Cursor Style", selection: Binding(
                    get: { prefs.cursorStyle },
                    set: { prefs.cursorStyle = $0 }
                )) {
                    ForEach(Preferences.CursorStyle.allCases, id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }

                Toggle("Blink Cursor Animation", isOn: Binding(
                    get: { prefs.cursorBlinks },
                    set: { prefs.cursorBlinks = $0 }
                ))

                Toggle("Show Line Numbers", isOn: Binding(
                    get: { prefs.showLineNumbers },
                    set: { prefs.showLineNumbers = $0 }
                ))

                Toggle("Highlight Matching Brackets", isOn: Binding(
                    get: { prefs.bracketMatchingHighlight },
                    set: { prefs.bracketMatchingHighlight = $0 }
                ))

                Toggle("Show Indent Guides in Code Blocks", isOn: Binding(
                    get: { prefs.showIndentGuides },
                    set: { prefs.showIndentGuides = $0 }
                ))
            }

            Section("Active Theme Palette") {
                if let activeTheme = themeManager.theme(for: settings.selectedThemeID) {
                    LiquidGlassCard(cornerRadius: 10, style: .standard) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Text("Color Tokens:")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)

                                ForEach([
                                    activeTheme.colors.background,
                                    activeTheme.colors.syntaxKeyword,
                                    activeTheme.colors.accent,
                                    activeTheme.colors.syntaxString
                                ], id: \.self) { hex in
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(hex: hex))
                                        .frame(width: 22, height: 22)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                                        )
                                }
                            }

                            Text("struct ContentView: View {\n    var body: some View {\n        Text(\"Hello, SwiftCode!\")\n            .padding()\n    }\n}")
                                .font(.custom(prefs.editorFontName, size: prefs.editorFontSize))
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(hex: activeTheme.colors.background))
                                .foregroundColor(Color(hex: activeTheme.colors.syntaxKeyword))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                )
                        }
                        .padding(12)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("App Icon") {
                ScrollView {
                    AppIconPickerView()
                        .padding(4)
                }
                .frame(height: 560)
            }
        }
        .formStyle(.grouped)
        .clipped()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if let bg = EditorTheme.color(prefs.customBackgroundColor) {
                customBgColor = Color(nsColor: bg)
            }
        }
    }
}

public struct NativeSourceControlSettingsView: View {
    @State private var prefs = Preferences.shared
    @State private var appSettings = AppSettings.shared

    private let fetchIntervalOptions = ["Never", "5m", "15m", "30m", "1h"]
    private let toolOptions = ["Built-in", "FileMerge", "Kaleidoscope", "Beyond Compare", "VS Code"]
    private let credHelperOptions = ["macOS Keychain", "Cache", "Store", "Custom"]

    public init() {}

    private func appSetting<T>(_ key: ReferenceWritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(get: { appSettings[keyPath: key] }, set: { appSettings[keyPath: key] = $0 })
    }

    private func pref<T>(_ key: ReferenceWritableKeyPath<Preferences, T>) -> Binding<T> {
        Binding(get: { prefs[keyPath: key] }, set: { prefs[keyPath: key] = $0 })
    }

    public var body: some View {
        Form {
            Section("General Source Control") {
                Toggle("Enable Source Control", isOn: pref(\.sourceControlEnabled))
            }

            Section("Git Executable") {
                TextField("Git executable path (/usr/bin/git)", text: appSetting(\.gitPath))
                Text("Leave empty to use git from the PATH. Used by commits, clones, and GitHub operations.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Git Identity") {
                TextField("Git Author Name", text: pref(\.customGitAuthorName))
                TextField("Git Author Email", text: pref(\.customGitAuthorEmail))
                Toggle("Allow Per-Repository Author Override", isOn: pref(\.perRepoAuthorOverride))

                TextField("Git config user.name", text: appSetting(\.gitUserName))
                TextField("Git config user.email", text: appSetting(\.gitUserEmail))
                Text("Git config name/email are used when SwiftCode writes git configuration for GitHub repositories.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Authentication") {
                TextField("SSH key path (~/.ssh/id_ed25519)", text: appSetting(\.sshKeyPath))
                SecureField("HTTPS auth token (ghp_…)", text: Binding(
                    get: { appSettings.httpsAuthToken },
                    set: { value in
                        appSettings.httpsAuthToken = value
                        if value.isEmpty {
                            KeychainService.shared.delete(forKey: KeychainService.githubToken)
                        } else {
                            KeychainService.shared.set(value, forKey: KeychainService.githubToken)
                        }
                    }
                ))
                Text("The token is also stored in the Keychain and shared with GitHub clone, pull request, and code-search features.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Branches & Workflow") {
                Picker("Default Initial Branch", selection: pref(\.defaultBranchName)) {
                    Text("main").tag("main")
                    Text("master").tag("master")
                    Text("develop").tag("develop")
                    Text("trunk").tag("trunk")
                }

                Picker("Auto-Fetch Interval", selection: pref(\.autoFetchInterval)) {
                    ForEach(fetchIntervalOptions, id: \.self) { interval in
                        Text(interval).tag(interval)
                    }
                }

                Toggle("Prune Remote Branches on Fetch", isOn: pref(\.pruneRemoteBranchesOnFetch))
                Toggle("Automatically Fetch Repositories in Background", isOn: appSetting(\.autoFetchRepositories))
                Toggle("Automatically Pull Before Committing", isOn: appSetting(\.autoPullBeforeCommit))

                Picker("Default Pull Strategy", selection: pref(\.pullStrategy)) {
                    ForEach(Preferences.pullStrategies, id: \.self) { strategy in
                        Text(strategy).tag(strategy)
                    }
                }

                Toggle("Set Upstream Automatically When Pushing", isOn: pref(\.pushSetsUpstreamAutomatically))

                Toggle("Show Inline Diff Indicators in Editor Gutter", isOn: pref(\.showInlineDiffGutter))
            }

            Section("Commit Signing") {
                Toggle("Enable Commit Signing (GPG / SSH)", isOn: pref(\.commitSigningEnabled))

                if prefs.commitSigningEnabled {
                    Picker("Signing Format", selection: pref(\.commitSigningType)) {
                        Text("GPG").tag("GPG")
                        Text("SSH").tag("SSH")
                    }

                    TextField("Signing Key ID / Path", text: pref(\.commitSigningKey))

                    Toggle("Sign Commits by Default", isOn: pref(\.signCommitsByDefault))
                    Toggle("Sign Tags by Default", isOn: pref(\.signTagsByDefault))
                }
            }

            Section("Committing") {
                TextField("Commit Message Template ([Feature] {message})", text: appSetting(\.commitMessageTemplate))
                Text("{message} is replaced with the commit subject; leave empty for the default message.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Editor & Diffs") {
                Toggle("Show Inline Blame", isOn: Binding(
                    get: { GitBlameSettings.showInlineBlame },
                    set: { GitBlameSettings.showInlineBlame = $0 }
                ))
                Toggle("Show Staged / Unstaged Split", isOn: pref(\.showStagedUnstagedSplit))
                Stepper(value: pref(\.diffContextLines), in: 0...10, step: 1) {
                    HStack {
                        Text("Diff Context Lines")
                        Spacer()
                        Text("\(prefs.diffContextLines)").foregroundStyle(.secondary).monospacedDigit()
                    }
                }
                Toggle("Show Stash List in Navigator", isOn: pref(\.showStashesInNavigator))
                Toggle("Show Tags in Navigator", isOn: pref(\.showTagsInNavigator))
                Toggle("Include Tags in History", isOn: pref(\.showTagsInHistory))
            }

            Section("External Tools & Credential Helper") {
                Picker("Diff Tool", selection: pref(\.diffTool)) {
                    ForEach(toolOptions, id: \.self) { tool in
                        Text(tool).tag(tool)
                    }
                }

                Picker("Merge Tool", selection: pref(\.mergeTool)) {
                    ForEach(toolOptions, id: \.self) { tool in
                        Text(tool).tag(tool)
                    }
                }

                Picker("Credential Helper", selection: pref(\.gitCredentialHelper)) {
                    ForEach(credHelperOptions, id: \.self) { helper in
                        Text(helper).tag(helper)
                    }
                }
            }

            Section("GitHub") {
                TextField("Default repository (owner/name)", text: appSetting(\.defaultGitHubRepo))
                Toggle("Monitor Repository Workflows", isOn: appSetting(\.workflowMonitoringEnabled))

                if !appSettings.savedRepositories.isEmpty {
                    ForEach(appSettings.savedRepositories) { repo in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(repo.owner)/\(repo.name)").font(.headline)
                                Text(repo.repositoryURL)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Remove") {
                                appSettings.removeRepository(repo)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }

                Text("Clone lists your repos automatically once a token is saved. Pull requests, issues & code search use the same token.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .clipped()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

public struct NativeCloudSettingsView: View {
    @AppStorage("com.swiftcode.cloud.syncEnabled") private var syncEnabled = false
    @State private var cloudManager = CloudManager.shared
    @State private var isSyncing = false
    @State private var syncStatusMessage: String?
    @State private var syncSuccess: Bool = true
    @State private var pendingQueueCount: Int = 0

    public init() {}

    public var body: some View {
        Form {
            Section("Synchronization") {
                Toggle("Continuous Real-Time Sync", isOn: $syncEnabled)
                    .onChange(of: syncEnabled) { _, newValue in
                        Task {
                            await CloudSyncEngine.shared.setSyncEnabled(newValue)
                        }
                    }

                Text("Automatically synchronize workspace settings, files, and templates with your remote cloud storage.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LabeledContent("Current State") {
                    Text(cloudManager.syncState.rawValue.capitalized)
                        .foregroundStyle(syncStateColor)
                        .font(.caption.bold())
                }

                LabeledContent("Last Synchronized") {
                    if let lastSync = cloudManager.lastSyncTime {
                        Text(lastSync.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                    } else {
                        Text("Never")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                LabeledContent("Pending Queue") {
                    Text("\(pendingQueueCount) items")
                        .font(.caption)
                }

                HStack {
                    Button {
                        triggerManualSync()
                    } label: {
                        HStack(spacing: 6) {
                            if isSyncing {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text("Sync Now")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSyncing)

                    if let message = syncStatusMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(syncSuccess ? .green : .red)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .clipped()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            refreshSyncInfo()
        }
    }

    private var syncStateColor: Color {
        switch cloudManager.syncState {
        case .idle: return .green
        case .syncing: return .blue
        case .paused: return .orange
        case .error: return .red
        }
    }

    private func refreshSyncInfo() {
        Task {
            pendingQueueCount = await SyncQueue.shared.getPendingUploadCount()
        }
    }

    private func triggerManualSync() {
        isSyncing = true
        syncStatusMessage = nil
        Task {
            await CloudSyncEngine.shared.triggerSync()
            refreshSyncInfo()
            isSyncing = false
            syncSuccess = true
            syncStatusMessage = "Sync completed successfully."
        }
    }
}

public struct NativeBackupsSettingsView: View {
    @State private var backups: [BackupManifest] = []
    @State private var showingCreateSheet = false
    @State private var selectedManifest: BackupManifest?
    @State private var restoreStatusMessage: String?
    @State private var isSuccessStatus = true
    @State private var manifestToRestore: BackupManifest?
    @State private var showRestoreConfirmation = false

    public init() {}

    public var body: some View {
        Form {
            Section("Snapshot Management") {
                Text("Point-in-time snapshots capture local preferences, syntax themes, project listings, and workspace configurations.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button("Create Backup Snapshot...") {
                        showingCreateSheet = true
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Refresh") {
                        loadBackups()
                    }
                }

                if let message = restoreStatusMessage {
                    HStack(spacing: 6) {
                        Image(systemName: isSuccessStatus ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(isSuccessStatus ? .green : .red)
                        Text(message)
                            .font(.caption.bold())
                            .foregroundStyle(isSuccessStatus ? .green : .red)
                    }
                }
            }

            Section("Saved Backups (\(backups.count))") {
                if backups.isEmpty {
                    Text("No backup snapshots created yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(backups) { manifest in
                        LiquidGlassCard(cornerRadius: 8, style: .subtle) {
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(manifest.filename.isEmpty ? "Snapshot \(manifest.backupID.prefix(8))" : manifest.filename)
                                        .font(.headline)

                                    HStack(spacing: 8) {
                                        Text(manifest.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        Text("•")
                                        Text(ByteCountFormatter.string(fromByteCount: manifest.sizeInBytes, countStyle: .file))
                                        if manifest.isCloudStored {
                                            Text("•")
                                            Text("Cloud").foregroundStyle(.blue)
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button("Details") {
                                    selectedManifest = manifest
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Button("Restore") {
                                    manifestToRestore = manifest
                                    showRestoreConfirmation = true
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                            .padding(10)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .clipped()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            loadBackups()
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateBackupView()
                .onDisappear {
                    loadBackups()
                }
        }
        .sheet(item: $selectedManifest) { manifest in
            NavigationStack {
                BackupDetailsView(manifest: manifest)
            }
            .onDisappear {
                loadBackups()
            }
        }
        .confirmationDialog(
            "Restore Backup Snapshot",
            isPresented: $showRestoreConfirmation,
            presenting: manifestToRestore
        ) { manifest in
            Button("Restore Snapshot", role: .destructive) {
                performRestore(manifest: manifest)
            }
            Button("Cancel", role: .cancel) {}
        } message: { manifest in
            Text("Are you sure you want to restore snapshot from \(manifest.createdAt.formatted())? Current unsaved settings may be overwritten.")
        }
    }

    private func loadBackups() {
        Task {
            BackupEngine.shared.loadLocalBackups()
            backups = BackupEngine.shared.backups
        }
    }

    private func performRestore(manifest: BackupManifest) {
        Task {
            do {
                _ = try await BackupEngine.shared.restore(manifest: manifest)
                isSuccessStatus = true
                restoreStatusMessage = "Restored successfully from \(manifest.filename)."
            } catch {
                isSuccessStatus = false
                restoreStatusMessage = "Restore failed: \(error.localizedDescription)"
            }
        }
    }
}

public struct NativeConnectSettingsView: View {
    @State private var connectServer = ConnectServer.shared
    @State private var bonjour = BonjourAdvertiser.shared
    @State private var diagnostics = ConnectDiagnostics.shared
    @State private var portString: String = ""
    @State private var portError: String?

    public init() {}

    public var body: some View {
        Form {
            Section("SwiftCode Connect Server") {
                Toggle("Server Running", isOn: Binding(
                    get: { connectServer.isRunning },
                    set: { shouldRun in
                        Task {
                            if shouldRun {
                                do {
                                    try await connectServer.startServer()
                                    portError = nil
                                } catch {
                                    portError = error.localizedDescription
                                }
                            } else {
                                connectServer.stopServer()
                                portError = nil
                            }
                        }
                    }
                ))

                LabeledContent("Server State") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(connectServer.isRunning ? Color.green : Color.secondary)
                            .frame(width: 8, height: 8)
                        Text(connectServer.isRunning ? "Active (Listening)" : "Stopped")
                            .font(.caption.bold())
                            .foregroundStyle(connectServer.isRunning ? .green : .secondary)
                    }
                }

                LabeledContent("Active Port") {
                    if let port = connectServer.activePort {
                        Text("\(port)")
                            .font(.system(.body, design: .monospaced))
                    } else {
                        Text("None")
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 8) {
                    TextField("Configured Port", text: $portString)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 140)

                    Button("Apply Port") {
                        if let port = UInt16(portString) {
                            Task {
                                do {
                                    try await connectServer.applyPort(port)
                                    portError = nil
                                } catch {
                                    portError = error.localizedDescription
                                }
                            }
                        } else {
                            portError = "Invalid port number. Must be between 1024 and 65535."
                        }
                    }
                }

                if let error = portError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Network & Bonjour Discovery") {
                LiquidGlassCard(cornerRadius: 10, style: .standard) {
                    VStack(alignment: .leading, spacing: 10) {
                        LabeledContent("Device Name") {
                            Text(bonjour.macName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Divider()

                        LabeledContent("Device ID") {
                            Text(bonjour.deviceID)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }

                        Divider()

                        LabeledContent("Local IP Address") {
                            Text(diagnostics.localIPAddress ?? "Not Available")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Divider()

                        LabeledContent("Bonjour Advertising") {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(bonjour.isAdvertising ? Color.green : Color.orange)
                                    .frame(width: 8, height: 8)
                                Text(bonjour.isAdvertising ? "Broadcasting to Local Network" : "Idle")
                                    .font(.caption)
                            }
                        }

                        Divider()

                        LabeledContent("Active Sessions") {
                            Text("\(connectServer.activeSessions.count) connected")
                                .font(.caption)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .formStyle(.grouped)
        .clipped()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            portString = "\(connectServer.configuredPort)"
            diagnostics.refreshLocalIP()
        }
    }
}

public struct NativeAssistSettingsView: View {
    @Environment(AppSettings.self) private var settings

    public init() {}

    public var body: some View {
        AssistSettingsView()
            .environment(settings)
            .clipped()
            .padding(.top, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
    }
}

public struct NativeComposioSettingsView: View {
    public init() {}

    public var body: some View {
        ScrollView {
            ComposioSettingsView()
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipped()
        .padding(.top, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}

public struct NativeOfflineModelsSettingsView: View {
    public init() {}

    public var body: some View {
        ScrollView {
            OfflineModelsView()
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipped()
        .padding(.top, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}

public struct NativePluginsSettingsView: View {
    public init() {}

    public var body: some View {
        ScrollView {
            PluginManagerView()
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipped()
        .padding(.top, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}

public struct NativeUpdatesSettingsView: View {
    public init() {}

    public var body: some View {
        ScrollView {
            UpdatesView()
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipped()
        .padding(.top, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}

public struct NativeCreditsSettingsView: View {
    public init() {}

    public var body: some View {
        ScrollView {
            CreditsView()
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipped()
        .padding(.top, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}
