import Foundation
import SwiftUI
import YcodeAssistant
import YcodeBuild
import YcodeIDECore
import YcodeIDEShell

@MainActor
private func appSetting<T>(_ key: ReferenceWritableKeyPath<AppSettings, T>) -> Binding<T> {
    Binding(get: { AppSettings.shared[keyPath: key] }, set: { AppSettings.shared[keyPath: key] = $0 })
}

private func prefBool(_ key: ReferenceWritableKeyPath<Preferences, Bool>) -> Binding<Bool> {
    Binding(get: { Preferences.shared[keyPath: key] }, set: { Preferences.shared[keyPath: key] = $0 })
}

private func prefString(_ key: ReferenceWritableKeyPath<Preferences, String>) -> Binding<String> {
    Binding(get: { Preferences.shared[keyPath: key] }, set: { Preferences.shared[keyPath: key] = $0 })
}

private func prefInt(_ key: ReferenceWritableKeyPath<Preferences, Int>) -> Binding<Int> {
    Binding(get: { Preferences.shared[keyPath: key] }, set: { Preferences.shared[keyPath: key] = $0 })
}

private func textField(_ title: String, _ binding: Binding<String>, width: CGFloat = 240) -> some View {
    SettingsRow(title) {
        TextField(title, text: binding, prompt: Text(verbatim: ""))
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 11, design: .monospaced))
            .frame(width: width)
    }
}

struct SourceControlSettingsPane: View {
    @State private var author: (name: String?, email: String?)?

    private static let fetchIntervals = ["Never", "5m", "15m", "30m", "1h"]
    private static let toolOptions = ["Built-in", "FileMerge", "Kaleidoscope", "Beyond Compare", "VS Code"]
    private static let credHelpers = ["macOS Keychain", "Cache", "Store", "Custom"]

    private var httpsToken: Binding<String> {
        Binding(get: { AppSettings.shared.httpsAuthToken }, set: { value in
            AppSettings.shared.httpsAuthToken = value
            if value.isEmpty {
                KeychainService.shared.delete(forKey: KeychainService.githubToken)
            } else {
                KeychainService.shared.set(value, forKey: KeychainService.githubToken)
            }
        })
    }

    var body: some View {
        let _ = ShellPreferences.shared.revision
        SettingsForm {
            SettingsSection {
                CheckRow(title: "Enable source control", isOn: setting(\.sourceControlEnabled), target: "settings source control")
            }
            SettingsSection("Git Executable") {
                textField("Git executable path", appSetting(\.gitPath))
            } footer: {
                FootNote(text: "Leave empty to use git from the PATH (/usr/bin/git). Used by commits, clones, and GitHub operations.")
            }
            SettingsSection("Git Identity", content: {
                textField("Author name (override)", prefString(\.customGitAuthorName))
                textField("Author email (override)", prefString(\.customGitAuthorEmail))
                CheckRow(title: "Allow per-repository identity override", isOn: prefBool(\.perRepoAuthorOverride),
                         target: "settings git per-repo override")
                textField("Git config user.name", appSetting(\.gitUserName))
                textField("Git config user.email", appSetting(\.gitUserEmail))
                ValueRow(title: "git config user.name", value: value(\.name), target: "settings git name")
                ValueRow(title: "git config user.email", value: value(\.email), target: "settings git email")
            }, footer: {
                FootNote(text: "Global defaults are read from git config (git config --global user.name and user.email); SwiftCode only reads it. The override fields take precedence when set.")
            })
            SettingsSection("Authentication") {
                textField("SSH key path", appSetting(\.sshKeyPath))
                SettingsRow("HTTPS auth token") {
                    SecureField("HTTPS auth token", text: httpsToken, prompt: Text(verbatim: "ghp_…"))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 240)
                }
            } footer: {
                FootNote(text: "The token is also stored in the Keychain and shared with GitHub clone, pull request, and code-search features.")
            }
            SettingsSection("Fetching & Updating") {
                PickerRow(title: "Auto-fetch interval", selection: prefString(\.autoFetchInterval),
                          options: Self.fetchIntervals.map { ($0, $0) }, target: "settings git fetch interval")
                CheckRow(title: "Prune remote branches on fetch", isOn: prefBool(\.pruneRemoteBranchesOnFetch),
                         target: "settings git prune")
                CheckRow(title: "Automatically fetch repositories", isOn: appSetting(\.autoFetchRepositories),
                         target: "settings git auto fetch repos")
                CheckRow(title: "Automatically pull before committing", isOn: appSetting(\.autoPullBeforeCommit),
                         target: "settings git auto pull")
                PickerRow(title: "Default pull strategy", selection: prefString(\.pullStrategy),
                          options: Preferences.pullStrategies.map { ($0, $0) }, target: "settings git pull strategy")
                CheckRow(title: "Set upstream automatically when pushing", isOn: prefBool(\.pushSetsUpstreamAutomatically),
                         target: "settings git push upstream")
            }
            SettingsSection("Committing") {
                CheckRow(title: "Enable commit signing (GPG / SSH)", isOn: prefBool(\.commitSigningEnabled),
                         target: "settings git commit signing")
                if Preferences.shared.commitSigningEnabled {
                    PickerRow(title: "Signing format", selection: prefString(\.commitSigningType),
                              options: [("GPG", "GPG"), ("SSH", "SSH")], target: "settings git signing type")
                    textField("Signing key ID / path", prefString(\.commitSigningKey))
                    CheckRow(title: "Sign commits by default", isOn: prefBool(\.signCommitsByDefault),
                             target: "settings git sign commits")
                    CheckRow(title: "Sign tags by default", isOn: prefBool(\.signTagsByDefault),
                             target: "settings git sign tags")
                }
                textField("Commit message template", appSetting(\.commitMessageTemplate))
            } footer: {
                FootNote(text: "{message} in the template is replaced with the commit subject; leave empty for the default message.")
            }
            SettingsSection("Editor & Diffs") {
                CheckRow(title: "Show inline diff indicators in editor gutter", isOn: prefBool(\.showInlineDiffGutter),
                         target: "settings git inline diff")
                CheckRow(title: "Show inline blame", isOn: Binding(get: { GitBlameSettings.showInlineBlame },
                                                                 set: { GitBlameSettings.showInlineBlame = $0 }),
                         target: "settings git inline blame")
                CheckRow(title: "Show staged / unstaged split", isOn: prefBool(\.showStagedUnstagedSplit),
                         target: "settings git staged split")
                IntStepperRow(title: "Diff context lines", value: prefInt(\.diffContextLines), range: 0...10,
                              target: "settings git diff context")
                CheckRow(title: "Show stash list in navigator", isOn: prefBool(\.showStashesInNavigator),
                         target: "settings git stashes")
                CheckRow(title: "Show tags in navigator", isOn: prefBool(\.showTagsInNavigator),
                         target: "settings git tags nav")
                CheckRow(title: "Include tags in history", isOn: prefBool(\.showTagsInHistory),
                         target: "settings git tags history")
            }
            SettingsSection("External Tools") {
                PickerRow(title: "Diff tool", selection: prefString(\.diffTool),
                          options: Self.toolOptions.map { ($0, $0) }, target: "settings git diff tool")
                PickerRow(title: "Merge tool", selection: prefString(\.mergeTool),
                          options: Self.toolOptions.map { ($0, $0) }, target: "settings git merge tool")
                PickerRow(title: "Credential helper", selection: prefString(\.gitCredentialHelper),
                          options: Self.credHelpers.map { ($0, $0) }, target: "settings git credential helper")
            }
            SettingsSection("GitHub", content: {
                textField("Default repository", appSetting(\.defaultGitHubRepo))
                CheckRow(title: "Monitor repository workflows", isOn: appSetting(\.workflowMonitoringEnabled),
                         target: "settings git workflow monitoring")
                ForEach(AppSettings.shared.savedRepositories) { repo in
                    SettingsRow("\(repo.owner)/\(repo.name)") {
                        HStack(spacing: 6) {
                            Text(verbatim: repo.repositoryURL)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(ShellColors(.light).secondaryLabel)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Button("Remove") { AppSettings.shared.removeRepository(repo) }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                }
            }, footer: {
                FootNote(text: "Clone lists your repos automatically once a token is saved. Pull requests, issues & code search use the same token.")
            })
        }
        .task {
            guard author == nil else { return }
            let read = await Task.detached { (name: GitGlobalConfig.value("user.name"), email: GitGlobalConfig.value("user.email")) }.value
            author = read
        }
    }

    func value(_ key: KeyPath<(name: String?, email: String?), String?>) -> String {
        guard let author else { return "Reading…" }
        return author[keyPath: key] ?? "Not set"
    }
}

struct LocationsSettingsPane: View {
    @State private var tools: [(title: String, path: String?)]?

    var body: some View {
        let _ = ShellPreferences.shared.revision
        SettingsForm {
            #if !os(Linux)
            SettingsSection("Build") {
                PickerRow(title: "Build System", selection: Binding(get: { BuildSystemPreference.current() }, set: { p in
                    p.save()
                    ShellPreferences.shared.touch()
                }), options: BuildSystemPreference.allCases.map { ($0, $0 == BuildSystemPreference.defaultValue ? "\($0.title) (Default)" : $0.title) },
                          target: "settings build system",
                          help: BuildSystemPreference.current() == .xcodebuild ? "Builds use xcodebuild."
                              : (SwiftBuildEngine.locate().map { "swbuild: \($0)" } ?? "The swift-build helper was not found; builds use xcodebuild."))
            }
            #endif
            SettingsSection("Build and Code Tools", content: {
                ForEach(tools ?? [], id: \.title) { t in
                    SettingsRow(t.title) { PathText(path: t.path) }
                }
                if tools == nil { ValueRow(title: "Tools", value: "Looking…") }
            }, footer: {
                FootNote(text: Self.engineNote)
            })
            SettingsSection("Files") {
                SettingsRow("Themes") { PathText(path: Preferences.shared.themesDirectory.path) }
                SettingsRow("Package build products") { PathText(path: ".build inside each package") }
            }
        }
        .task {
            guard tools == nil else { return }
            tools = await Task.detached { Self.locateTools() }.value
        }
    }

    #if os(Linux)
    static let engineNote = "Packages build with SwiftPM (swift build); projects and workspaces with swiftcodebuild. Tools are found on the PATH."
    #else
    static let engineNote = "Tools are found on the PATH; swiftcodebuild also next to SwiftCode."
    #endif

    nonisolated static func locateTools() -> [(title: String, path: String?)] {
        [("Swift", ShellToolchain.locate("swift")), ("Language server", ShellToolchain.locate("sourcekit-lsp")),
         ("Project builds", TestRunnerSelection.locateSwiftCodebuild()), ("Git", ShellToolchain.locate("git"))]
    }
}

struct ComponentsSettingsPane: View {
    @Environment(\.colorScheme) private var scheme

    static let emptyTitle = "No Components"
    static let emptyText = "SwiftCode on Linux builds with the Swift toolchain on the PATH (Settings › Locations). Simulator runtimes are added with the runtime wizard."

    var body: some View {
        let p = SettingsPalette(scheme)
        SettingsForm {
            SettingsSection("Installed") {
                SettingsContentRow(inset: 0) {
                    VStack(spacing: 6) {
                        Text(verbatim: Self.emptyTitle).font(SettingsFonts.header).foregroundStyle(p.help)
                            .shellTarget("settings components empty")
                        SettingsHelpText(text: Self.emptyText).multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 30)
                    .frame(maxWidth: .infinity, minHeight: 140)
                }
                SettingsRow("Simulator runtimes") {
                    Button("Simulator Runtimes…") { ShellApp.model.showRuntimeSetup(step: .runtimes) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .shellTarget("settings components runtimes")
                }
            }
        }
    }
}

struct PathText: View {
    var path: String?
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let c = ShellColors(scheme)
        Text(verbatim: path.map(Self.tilde) ?? "Not found")
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(path == nil ? c.error : c.secondaryLabel)
            .lineLimit(1)
            .truncationMode(.middle)
    }

    static func tilde(_ p: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return p.hasPrefix(home + "/") ? "~" + p.dropFirst(home.count) : p
    }
}
