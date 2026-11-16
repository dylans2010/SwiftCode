import Foundation
import YcodeAssistant

@MainActor
public final class Preferences {
    public static let didChange = Notification.Name("SwiftCodePreferencesDidChange")
    public static var shared = Preferences()

    public let defaults: UserDefaults
    public let themesDirectory: URL

    public init(defaults: UserDefaults = .standard, themesDirectory: URL? = nil) {
        self.defaults = defaults
        self.themesDirectory = themesDirectory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SwiftCode/Themes")
        registerFactoryDefaults()
    }

    package func changed() { NotificationCenter.default.post(name: Self.didChange, object: self) }

    public static let factoryDefaults: [String: Any] = ["minimap": true]

    public func registerFactoryDefaults() {
        defaults.register(defaults: Dictionary(uniqueKeysWithValues: Self.factoryDefaults.map { ("SwiftCode.\($0.key)", $0.value) }))
    }

    func get<T>(_ key: String, _ fallback: T) -> T { defaults.object(forKey: "SwiftCode.\(key)") as? T ?? fallback }
    func set(_ key: String, _ value: Any?) { defaults.set(value, forKey: "SwiftCode.\(key)"); changed() }

    public enum Appearance: String, CaseIterable, Sendable { case system = "System", light = "Light", dark = "Dark" }
    public var appearance: Appearance {
        get { Appearance(rawValue: get("appearance", "System")) ?? .system }
        set { set("appearance", newValue.rawValue) }
    }
    public var welcomeStyleInterface: WelcomeStyleInterface {
        get {
            let raw = defaults.string(forKey: "SwiftCode.welcomeStyleInterface")
                ?? defaults.string(forKey: "welcomeStyleInterface")
                ?? WelcomeStyleInterface.style27.rawValue
            return WelcomeStyleInterface(rawValue: raw) ?? .style27
        }
        set {
            defaults.set(newValue.rawValue, forKey: "SwiftCode.welcomeStyleInterface")
            defaults.set(newValue.rawValue, forKey: "welcomeStyleInterface")
            changed()
            NotificationCenter.default.post(name: NSNotification.Name("WelcomeStyleDidChange"), object: newValue)
        }
    }
    public enum FileExtensions: String, CaseIterable, Sendable { case hide = "Hide All", show = "Show All" }
    public var fileExtensions: FileExtensions {
        get { FileExtensions(rawValue: get("fileExtensions", FileExtensions.hide.rawValue)) ?? .hide }
        set { set("fileExtensions", newValue.rawValue) }
    }
    public var showLiveIssues: Bool { get { get("showLiveIssues", true) } set { set("showLiveIssues", newValue) } }

    public enum Event: String, CaseIterable, Sendable {
        case buildStarts = "When build starts", buildErrors = "When build generates errors"
        case buildWarnings = "When build generates warnings", buildSucceeds = "When build succeeds", buildFails = "When build fails"
        case runStarts = "When running starts", runPauses = "When running pauses", runOutput = "When running generates output"
        case runEnds = "When running completes", runExitsUnexpectedly = "When running exits unexpectedly"
        case testSucceeds = "When testing succeeds", testFails = "When testing fails"

        public var category: String { rawValue.contains("build") ? "Build" : (rawValue.contains("testing") ? "Testing" : "Running") }
    }

    public static let behaviorCategories = ["Build", "Testing", "Running", "Search", "Localization Import / Export", "File",
                                            "Intelligence", "Playgrounds"]

    nonisolated public static let showDebuggerAction = "Debugger: Show Current Views"
    nonisolated public static let hideDebuggerAction = "Debugger: Hide Debugger"
    nonisolated public static let hideDebuggerIfNoOutputAction = "Debugger: Hide Debugger If No Output"
    nonisolated public static let notifyAction = "Notify with bezel or system notification"

    public struct Behavior: Codable, Equatable, Sendable {
        public var showNavigator: Int?
        public var showDebugArea: Bool?
        public var sound: String?
        public var notify = false
        public var hideDebugAreaIfNoOutput = false
        public init(showNavigator: Int? = nil, showDebugArea: Bool? = nil, sound: String? = nil, notify: Bool = false,
                    hideDebugAreaIfNoOutput: Bool = false) {
            self.showNavigator = showNavigator
            self.showDebugArea = showDebugArea
            self.sound = sound
            self.notify = notify
            self.hideDebugAreaIfNoOutput = hideDebugAreaIfNoOutput
        }
        public init(from d: Decoder) throws {
            let c = try d.container(keyedBy: CodingKeys.self)
            showNavigator = try c.decodeIfPresent(Int.self, forKey: .showNavigator)
            showDebugArea = try c.decodeIfPresent(Bool.self, forKey: .showDebugArea)
            sound = try c.decodeIfPresent(String.self, forKey: .sound)
            notify = try c.decodeIfPresent(Bool.self, forKey: .notify) ?? false
            hideDebugAreaIfNoOutput = try c.decodeIfPresent(Bool.self, forKey: .hideDebugAreaIfNoOutput) ?? false
        }

        public var actionTitles: [String] {
            var a: [String] = []
            if let n = showNavigator, CommandTable.navigators.indices.contains(n) { a.append("Navigator: \(CommandTable.navigators[n])") }
            if let d = showDebugArea { a.append(d ? Preferences.showDebuggerAction : Preferences.hideDebuggerAction) }
            if hideDebugAreaIfNoOutput { a.append(Preferences.hideDebuggerIfNoOutputAction) }
            if let s = sound { a.append("Play Sound: \(s)") }
            if notify { a.append(Preferences.notifyAction) }
            return a
        }
    }

    public static let defaultBehaviors: [Event: Behavior] = [
        .buildErrors: Behavior(showNavigator: 4), .buildSucceeds: Behavior(notify: true), .buildFails: Behavior(notify: true),
        .runPauses: Behavior(showNavigator: 6, showDebugArea: true), .runOutput: Behavior(showDebugArea: true),
        .runEnds: Behavior(hideDebugAreaIfNoOutput: true),
        .testSucceeds: Behavior(notify: true), .testFails: Behavior(notify: true),
    ]

    public func behavior(_ e: Event) -> Behavior {
        if let data = defaults.data(forKey: "SwiftCode.behavior.\(e)"), let b = try? JSONDecoder().decode(Behavior.self, from: data) { return b }
        return Self.defaultBehaviors[e] ?? Behavior()
    }

    public func setBehavior(_ b: Behavior, for e: Event) {
        defaults.set(try? JSONEncoder().encode(b), forKey: "SwiftCode.behavior.\(e)")
        changed()
    }

    public var showLineNumbers: Bool { get { get("lineNumbers", true) } set { set("lineNumbers", newValue) } }
    public var showFoldingRibbon: Bool { get { get("foldingRibbon", false) } set { set("foldingRibbon", newValue) } }
    public var showMinimap: Bool { get { get("minimap", Self.factoryDefaults["minimap"] as? Bool ?? true) } set { set("minimap", newValue) } }
    public var showPageGuide: Bool { get { get("pageGuide", false) } set { set("pageGuide", newValue) } }
    public var pageGuideColumn: Int { get { get("pageGuideColumn", 80) } set { set("pageGuideColumn", max(1, newValue)) } }
    public var indentWithTabs: Bool { get { get("indentWithTabs", false) } set { set("indentWithTabs", newValue) } }
    public var tabWidth: Int { get { get("tabWidth", 4) } set { set("tabWidth", max(1, min(16, newValue))) } }
    public var indentWidth: Int { get { get("indentWidth", 4) } set { set("indentWidth", max(1, min(16, newValue))) } }
    public var trimTrailingWhitespace: Bool { get { get("trimWhitespace", true) } set { set("trimWhitespace", newValue) } }
    public var wrapLines: Bool { get { get("wrapLines", true) } set { set("wrapLines", newValue) } }
    public var wrappedLineIndent: Int { get { get("wrappedLineIndent", 4) } set { set("wrappedLineIndent", max(0, min(16, newValue))) } }
    public var highlightSelectedSymbol: Bool { get { get("highlightSelectedSymbol", true) } set { set("highlightSelectedSymbol", newValue) } }
    public var highlightDelay: Double { get { get("highlightDelay", 0.25) } set { set("highlightDelay", max(0, min(5, newValue))) } }
    public var showInvisibles: Bool { get { get("showInvisibles", false) } set { set("showInvisibles", newValue) } }
    public var showCodeCoverage: Bool { get { get("showCodeCoverage", false) } set { set("showCodeCoverage", newValue) } }
    public var trimWhitespaceOnlyLines: Bool { get { get("trimWhitespaceOnlyLines", false) } set { set("trimWhitespaceOnlyLines", newValue) } }

    
    public var customBackgroundColor: String {
        get { get("customBackgroundColor", "") }
        set { set("customBackgroundColor", newValue) }
    }
    public var customAccentColor: String {
        get { get("customAccentColor", "") }
        set { set("customAccentColor", newValue) }
    }
    
    
    public var editorFontName: String {
        get { get("editorFontName", "") }
        set { set("editorFontName", newValue) }
    }
    public var editorFontSize: Double {
        get { get("editorFontSize", 13.0) }
        set { set("editorFontSize", max(10, min(28, newValue))) }
    }
    public var lineSpacingFactor: Double {
        get { get("lineSpacingFactor", 1.2) }
        set { set("lineSpacingFactor", max(1.0, min(2.0, newValue))) }
    }
    public enum CursorStyle: String, CaseIterable, Sendable {
        case bar = "Vertical Bar"
        case block = "Block"
        case underline = "Underline"
    }
    public var cursorStyle: CursorStyle {
        get { CursorStyle(rawValue: get("cursorStyle", CursorStyle.bar.rawValue)) ?? .bar }
        set { set("cursorStyle", newValue.rawValue) }
    }
    public var cursorBlinks: Bool {
        get { get("cursorBlinks", true) }
        set { set("cursorBlinks", newValue) }
    }
    public var bracketMatchingHighlight: Bool {
        get { get("bracketMatchingHighlight", true) }
        set { set("bracketMatchingHighlight", newValue) }
    }
    public var showIndentGuides: Bool {
        get { get("showIndentGuides", true) }
        set { set("showIndentGuides", newValue) }
    }

    
    public var defaultBranchName: String {
        get { get("defaultBranchName", "main") }
        set { set("defaultBranchName", newValue) }
    }
    public var commitSigningEnabled: Bool {
        get { get("commitSigningEnabled", false) }
        set { set("commitSigningEnabled", newValue) }
    }
    public var commitSigningType: String {
        get { get("commitSigningType", "GPG") }
        set { set("commitSigningType", newValue) }
    }
    public var commitSigningKey: String {
        get { get("commitSigningKey", "") }
        set { set("commitSigningKey", newValue) }
    }
    public var signCommitsByDefault: Bool {
        get { get("signCommitsByDefault", false) }
        set { set("signCommitsByDefault", newValue) }
    }
    public var signTagsByDefault: Bool {
        get { get("signTagsByDefault", false) }
        set { set("signTagsByDefault", newValue) }
    }
    public var autoFetchInterval: String {
        get { get("autoFetchInterval", "15m") }
        set { set("autoFetchInterval", newValue) }
    }
    public var pruneRemoteBranchesOnFetch: Bool {
        get { get("pruneRemoteBranchesOnFetch", false) }
        set { set("pruneRemoteBranchesOnFetch", newValue) }
    }
    
    
    nonisolated public static let pullStrategies = ["Fast-forward only", "Merge", "Rebase"]
    nonisolated public static let defaultPullStrategy = "Fast-forward only"
    public var pullStrategy: String {
        get { get("pullStrategy", Self.defaultPullStrategy) }
        set { set("pullStrategy", Self.pullStrategies.contains(newValue) ? newValue : Self.defaultPullStrategy) }
    }
    public var pullStyle: GitRepository.PullStyle {
        switch pullStrategy {
        case "Merge": .merge
        case "Rebase": .rebase
        default: .fastForwardOnly
        }
    }
    
    
    public nonisolated static var storedPullStyle: GitRepository.PullStyle {
        switch UserDefaults.standard.object(forKey: "SwiftCode.pullStrategy") as? String ?? defaultPullStrategy {
        case "Merge": .merge
        case "Rebase": .rebase
        default: .fastForwardOnly
        }
    }
    public var pushSetsUpstreamAutomatically: Bool {
        get { get("pushSetsUpstreamAutomatically", true) }
        set { set("pushSetsUpstreamAutomatically", newValue) }
    }
    public nonisolated static let defaultDiffContextLines = 3
    public var diffContextLines: Int {
        get { get("diffContextLines", Self.defaultDiffContextLines) }
        set { set("diffContextLines", max(0, min(10, newValue))) }
    }
    
    public nonisolated static var storedDiffContextLines: Int {
        max(0, min(10, UserDefaults.standard.object(forKey: "SwiftCode.diffContextLines") as? Int ?? defaultDiffContextLines))
    }
    public var showStashesInNavigator: Bool {
        get { get("showStashesInNavigator", true) }
        set { set("showStashesInNavigator", newValue) }
    }
    public var showTagsInNavigator: Bool {
        get { get("showTagsInNavigator", true) }
        set { set("showTagsInNavigator", newValue) }
    }
    public var showTagsInHistory: Bool {
        get { get("showTagsInHistory", true) }
        set { set("showTagsInHistory", newValue) }
    }
    public var showStagedUnstagedSplit: Bool {
        get { get("showStagedUnstagedSplit", true) }
        set { set("showStagedUnstagedSplit", newValue) }
    }
    public var showInlineDiffGutter: Bool {
        get { get("showInlineDiffGutter", true) }
        set { set("showInlineDiffGutter", newValue) }
    }
    public var customGitAuthorName: String {
        get { get("customGitAuthorName", "") }
        set { set("customGitAuthorName", newValue) }
    }
    public var customGitAuthorEmail: String {
        get { get("customGitAuthorEmail", "") }
        set { set("customGitAuthorEmail", newValue) }
    }
    public var perRepoAuthorOverride: Bool {
        get { get("perRepoAuthorOverride", false) }
        set { set("perRepoAuthorOverride", newValue) }
    }
    public var diffTool: String {
        get { get("diffTool", "Built-in") }
        set { set("diffTool", newValue) }
    }
    public var mergeTool: String {
        get { get("mergeTool", "Built-in") }
        set { set("mergeTool", newValue) }
    }
    public var gitCredentialHelper: String {
        get { get("gitCredentialHelper", "macOS Keychain") }
        set { set("gitCredentialHelper", newValue) }
    }

    public var sourceFontSize: Double? {
        get { (defaults.object(forKey: "SwiftCode.sourceFontSize") as? NSNumber)?.doubleValue }
        set { set("sourceFontSize", newValue.map { max(Self.fontSizeRange.lowerBound, min(Self.fontSizeRange.upperBound, $0)) }) }
    }
    public static let fontSizeRange: ClosedRange<Double> = 6...48

    public var indentUnit: String { indentWithTabs ? "\t" : String(repeating: " ", count: indentWidth) }

    public var autoIndent: Bool { get { get("autoIndent", true) } set { set("autoIndent", newValue) } }
    public var autoInsertClosers: Bool { get { get("autoInsertClosers", true) } set { set("autoInsertClosers", newValue) } }
    public var encloseSelection: Bool { get { get("encloseSelection", true) } set { set("encloseSelection", newValue) } }
    public var tabKeyBehavior: TabKeyBehavior {
        get { TabKeyBehavior(rawValue: get("tabKey", TabKeyBehavior.indentsInLeadingWhitespace.rawValue)) ?? .indentsInLeadingWhitespace }
        set { set("tabKey", newValue.rawValue) }
    }
    public var typingOptions: TypingOptions {
        TypingOptions(indent: IndentOptions(usesTabs: indentWithTabs, tabWidth: tabWidth, indentWidth: indentWithTabs ? tabWidth : indentWidth),
                      autoIndent: autoIndent, autoClose: autoInsertClosers, encloseSelection: encloseSelection, tabKey: tabKeyBehavior)
    }

    public var sourceControlEnabled: Bool { get { get("sourceControl", true) } set { set("sourceControl", newValue) } }
    
    public var sourceControlSystem: String { get { get("sourceControlSystem", "git") } set { set("sourceControlSystem", newValue) } }
    public var usesSpacesSourceControl: Bool { sourceControlSystem == "spaces" }

    public var spacesDefaultBranch: String {
        get { get("spacesDefaultBranch", "main") }
        set {
            set("spacesDefaultBranch", newValue)
            UserDefaults.standard.set(newValue, forKey: "spacesDefaultBranch")
        }
    }
    public var spacesAuthorName: String {
        get { get("spacesAuthorName", "") }
        set { set("spacesAuthorName", newValue) }
    }
    public var spacesAuthorEmail: String {
        get { get("spacesAuthorEmail", "") }
        set { set("spacesAuthorEmail", newValue) }
    }
    public var spacesLFSEnabled: Bool {
        get { get("spacesLFSEnabled", true) }
        set { set("spacesLFSEnabled", newValue) }
    }
    public var spacesLFSThresholdMB: Int {
        get { get("spacesLFSThresholdMB", 10) }
        set { set("spacesLFSThresholdMB", newValue) }
    }
    public var spacesPreserveFileMode: Bool {
        get { get("spacesPreserveFileMode", true) }
        set { set("spacesPreserveFileMode", newValue) }
    }
    public var spacesAllowSymlinks: Bool {
        get { get("spacesAllowSymlinks", true) }
        set { set("spacesAllowSymlinks", newValue) }
    }
    public var spacesAutoCRLF: Bool {
        get { get("spacesAutoCRLF", false) }
        set { set("spacesAutoCRLF", newValue) }
    }
    public var spacesIntegrityCheck: Bool {
        get { get("spacesIntegrityCheck", true) }
        set { set("spacesIntegrityCheck", newValue) }
    }

    public var showRegisters: Bool { get { get("showRegisters", false) } set { set("showRegisters", newValue) } }

    public var themeName: String {
        get { get("theme", EditorTheme.builtIns[0].name) }
        set { set("theme", newValue) }
    }

    public var themes: [EditorTheme] {
        let user = ((try? FileManager.default.contentsOfDirectory(at: themesDirectory, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "swiftcodetheme" }
            .compactMap { try? EditorTheme.read($0) }
            .sorted { $0.name < $1.name }
        return EditorTheme.builtIns + user.filter { u in !EditorTheme.builtIns.contains { $0.name == u.name } }
    }

    public var theme: EditorTheme { themes.first { $0.name == themeName } ?? EditorTheme.builtIns[0] }

    public func save(_ t: EditorTheme) throws {
        guard !EditorTheme.builtIns.contains(where: { $0.name == t.name }) else { throw CocoaError(.fileWriteNoPermission) }
        try FileManager.default.createDirectory(at: themesDirectory, withIntermediateDirectories: true)
        try t.write(to: themesDirectory.appendingPathComponent(t.fileName))
        themeName = t.name
    }

    @discardableResult
    public func duplicate(_ t: EditorTheme) throws -> EditorTheme {
        var copy = t
        var n = "\(t.name) Copy", i = 2
        while themes.contains(where: { $0.name == n }) { n = "\(t.name) Copy \(i)"; i += 1 }
        copy.name = n
        try save(copy)
        return copy
    }

    public func deleteTheme(named name: String) {
        guard let t = themes.first(where: { $0.name == name }), !EditorTheme.builtIns.contains(where: { $0.name == name }) else { return }
        try? FileManager.default.removeItem(at: themesDirectory.appendingPathComponent(t.fileName))
        if themeName == name { themeName = EditorTheme.builtIns[0].name } else { changed() }
    }

    @discardableResult
    public func importTheme(from url: URL) throws -> EditorTheme {
        let t = try EditorTheme.read(url)
        try save(t)
        return t
    }

    public func exportTheme(_ t: EditorTheme, to url: URL) throws { try t.write(to: url) }

    public struct Shortcut: Codable, Equatable, Hashable, Sendable {
        public var key: String
        public var modifiers: Int
        public init(key: String, modifiers: MenuCommand.Modifiers) {
            self.key = key.lowercased()
            self.modifiers = modifiers.rawValue
        }
        public var mods: MenuCommand.Modifiers { MenuCommand.Modifiers(rawValue: modifiers) }
    }

    public var keyBindingOverrides: [String: Shortcut] {
        get {
            guard let d = defaults.data(forKey: "SwiftCode.keyBindings"), let m = try? JSONDecoder().decode([String: Shortcut].self, from: d) else { return [:] }
            return m
        }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: "SwiftCode.keyBindings"); changed() }
    }
}

public struct EditorTheme: Codable, Equatable, Sendable {
    public var name: String
    public var fontName: String
    public var fontSize: Double
    public var background: String?
    public var foreground: String?
    public var selection: String?
    public var currentLine: String?
    public var tokens: [String: String]
    public var consoleFontName: String
    public var consoleFontSize: Double
    public var consoleBackground: String?
    public var consoleText: String?
    public var tokenFonts: [String: FontSpec]?

    public init(
        name: String,
        fontName: String = "",
        fontSize: Double = 13.0,
        background: String? = nil,
        foreground: String? = nil,
        selection: String? = nil,
        currentLine: String? = nil,
        tokens: [String: String] = [:],
        consoleFontName: String = "",
        consoleFontSize: Double = 11.0,
        consoleBackground: String? = nil,
        consoleText: String? = nil,
        tokenFonts: [String: FontSpec]? = nil
    ) {
        self.name = name
        self.fontName = fontName
        self.fontSize = fontSize
        self.background = background
        self.foreground = foreground
        self.selection = selection
        self.currentLine = currentLine
        self.tokens = tokens
        self.consoleFontName = consoleFontName
        self.consoleFontSize = consoleFontSize
        self.consoleBackground = consoleBackground
        self.consoleText = consoleText
        self.tokenFonts = tokenFonts
    }

    public struct FontSpec: Codable, Equatable, Sendable {
        public var name: String
        public var size: Double
        public init(name: String, size: Double) {
            self.name = name
            self.size = size
        }
    }

    public var fontSpec: FontSpec { FontSpec(name: fontName, size: fontSize) }
    public var consoleFontSpec: FontSpec { FontSpec(name: consoleFontName, size: consoleFontSize) }

    public var fileName: String { name.replacingOccurrences(of: "/", with: "-") + ".swiftcodetheme" }

    public static func read(_ url: URL) throws -> EditorTheme {
        try JSONDecoder().decode(EditorTheme.self, from: Data(contentsOf: url))
    }

    public func write(to url: URL) throws {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        try e.encode(self).write(to: url, options: .atomic)
    }
}

extension EditorTheme: Identifiable {
    public var id: String { name }
    public var keywordColor: String { tokens["keyword"] ?? "#FF7AB2" }
    public var stringColor: String { tokens["string"] ?? "#FF8170" }
    public var typeColor: String { tokens["type"] ?? "#6BDFFF" }

    public static func themeColor(_ hex: String?) -> ThemeColor? { ThemeColor(hex: hex) }

    public static let builtIns: [EditorTheme] = [
        EditorTheme(name: "SwiftCode Default", fontName: "", fontSize: 13, background: nil, foreground: nil, selection: nil, currentLine: nil,
                    tokens: [:], consoleFontName: "", consoleFontSize: 11, consoleBackground: nil, consoleText: nil),
        EditorTheme(name: "Xcode Dark", fontName: "SF Mono", fontSize: 13, background: "#1F2024", foreground: "#DFDFDF", selection: "#3A3D45", currentLine: "#282A30",
                    tokens: ["keyword": "#FC5FA3", "comment": "#6C7986", "docComment": "#8391A0", "string": "#FC6A5D", "number": "#D0BF69",
                             "preprocessor": "#FC5FA3", "attribute": "#FC5FA3", "typeName": "#5DD8FF"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#18191D", consoleText: "#DFDFDF"),
        EditorTheme(name: "Xcode Light", fontName: "SF Mono", fontSize: 13, background: "#FFFFFF", foreground: "#000000", selection: "#B4D8FD", currentLine: "#F2F4F7",
                    tokens: ["keyword": "#AD3DA4", "comment": "#707F8C", "docComment": "#43820D", "string": "#C41A16", "number": "#1C00CF",
                             "preprocessor": "#643820", "attribute": "#836C28", "typeName": "#4B21B0"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#F2F2F7", consoleText: "#000000"),
        EditorTheme(name: "Midnight Purple", fontName: "SF Mono", fontSize: 13, background: "#130A2A", foreground: "#E0D7F5", selection: "#3D2470", currentLine: "#1F1240",
                    tokens: ["keyword": "#C084FC", "comment": "#7E6B9B", "docComment": "#A78BFA", "string": "#F472B6", "number": "#FDE047",
                             "preprocessor": "#E879F9", "attribute": "#F43F5E", "typeName": "#818CF8"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#0E0720", consoleText: "#E0D7F5"),
        EditorTheme(name: "Cyberpunk", fontName: "SF Mono", fontSize: 13, background: "#120B1F", foreground: "#EAEAEA", selection: "#371859", currentLine: "#211238",
                    tokens: ["keyword": "#FF007F", "comment": "#716585", "docComment": "#00FF9F", "string": "#FFE600", "number": "#00FF9F",
                             "preprocessor": "#00F0FF", "attribute": "#FF007F", "typeName": "#00F0FF"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#0A0512", consoleText: "#00FF9F"),
        EditorTheme(name: "Solarized Dark", fontName: "SF Mono", fontSize: 13, background: "#002B36", foreground: "#839496", selection: "#073642", currentLine: "#073642",
                    tokens: ["keyword": "#859900", "comment": "#586E75", "docComment": "#657B83", "string": "#2AA198", "number": "#D33682",
                             "preprocessor": "#CB4B16", "attribute": "#B58900", "typeName": "#268BD2"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#073642", consoleText: "#839496"),
        EditorTheme(name: "Solarized Light", fontName: "SF Mono", fontSize: 13, background: "#FDF6E3", foreground: "#657B83", selection: "#EEE8D5", currentLine: "#F5EFDC",
                    tokens: ["keyword": "#859900", "comment": "#93A1A1", "docComment": "#586E75", "string": "#2AA198", "number": "#D33682",
                             "preprocessor": "#CB4B16", "attribute": "#B58900", "typeName": "#268BD2"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#EEE8D5", consoleText: "#657B83"),
        EditorTheme(name: "Monokai Pro", fontName: "SF Mono", fontSize: 13, background: "#2D2A2E", foreground: "#FCFCFA", selection: "#403E41", currentLine: "#3A363B",
                    tokens: ["keyword": "#FF6188", "comment": "#727072", "docComment": "#A9DC76", "string": "#FFD866", "number": "#AB9DF2",
                             "preprocessor": "#FC9867", "attribute": "#78DCE8", "typeName": "#78DCE8"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#221F22", consoleText: "#FCFCFA"),
        EditorTheme(name: "Dracula", fontName: "SF Mono", fontSize: 13, background: "#282A36", foreground: "#F8F8F2", selection: "#44475A", currentLine: "#343746",
                    tokens: ["keyword": "#FF79C6", "comment": "#6272A4", "docComment": "#50FA7B", "string": "#F1FA8C", "number": "#BD93F9",
                             "preprocessor": "#FFB86C", "attribute": "#8BE9FD", "typeName": "#8BE9FD"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#21222C", consoleText: "#F8F8F2"),
        EditorTheme(name: "Gruvbox Dark", fontName: "SF Mono", fontSize: 13, background: "#282828", foreground: "#EBDBB2", selection: "#3C3836", currentLine: "#32302F",
                    tokens: ["keyword": "#FB4934", "comment": "#928374", "docComment": "#B8BB26", "string": "#B8BB26", "number": "#D3869B",
                             "preprocessor": "#FE8019", "attribute": "#FABD2F", "typeName": "#83A598"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#1D2021", consoleText: "#EBDBB2"),
        EditorTheme(name: "Nord", fontName: "SF Mono", fontSize: 13, background: "#2E3440", foreground: "#D8DEE9", selection: "#3B4252", currentLine: "#434C5E",
                    tokens: ["keyword": "#81A1C1", "comment": "#4C566A", "docComment": "#A3BE8C", "string": "#A3BE8C", "number": "#B48EAD",
                             "preprocessor": "#88C0D0", "attribute": "#EBCB8B", "typeName": "#8FBCBB"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#242933", consoleText: "#D8DEE9"),
        EditorTheme(name: "One Dark", fontName: "SF Mono", fontSize: 13, background: "#282C34", foreground: "#ABB2BF", selection: "#3E4451", currentLine: "#2C313A",
                    tokens: ["keyword": "#C678DD", "comment": "#5C6370", "docComment": "#98C379", "string": "#98C379", "number": "#D19A66",
                             "preprocessor": "#E5C07B", "attribute": "#61AFEF", "typeName": "#E5C07B"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#21252B", consoleText: "#ABB2BF"),
        EditorTheme(name: "Synthwave '84", fontName: "SF Mono", fontSize: 13, background: "#262335", foreground: "#FFFFFF", selection: "#34294F", currentLine: "#2A263B",
                    tokens: ["keyword": "#FF7EDB", "comment": "#6A6A87", "docComment": "#36F9F6", "string": "#FEDE5D", "number": "#F97E72",
                             "preprocessor": "#FE4450", "attribute": "#72F1B8", "typeName": "#36F9F6"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#1A1626", consoleText: "#FFFFFF"),
        EditorTheme(name: "Tokyo Night", fontName: "SF Mono", fontSize: 13, background: "#1A1B26", foreground: "#C0CAF5", selection: "#283457", currentLine: "#24283B",
                    tokens: ["keyword": "#BB9AF7", "comment": "#565F89", "docComment": "#9ECE6A", "string": "#9ECE6A", "number": "#FF9E64",
                             "preprocessor": "#7DCFFF", "attribute": "#E0AF68", "typeName": "#7AA2F7"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#16161E", consoleText: "#C0CAF5"),
        EditorTheme(name: "Catppuccin Mocha", fontName: "SF Mono", fontSize: 13, background: "#1E1E2E", foreground: "#CDD6F4", selection: "#313244", currentLine: "#2A2B3D",
                    tokens: ["keyword": "#CBA6F7", "comment": "#6C7086", "docComment": "#A6E3A1", "string": "#A6E3A1", "number": "#FAB387",
                             "preprocessor": "#F38BA8", "attribute": "#F9E2AF", "typeName": "#89DCEB"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#181825", consoleText: "#CDD6F4"),
        EditorTheme(name: "Catppuccin Latte", fontName: "SF Mono", fontSize: 13, background: "#EFF1F5", foreground: "#4C4F69", selection: "#CCD0DA", currentLine: "#E6E9EF",
                    tokens: ["keyword": "#8839EF", "comment": "#9CA0B0", "docComment": "#40A02B", "string": "#40A02B", "number": "#FE640B",
                             "preprocessor": "#D20F39", "attribute": "#DF8E1D", "typeName": "#1E66F5"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#E6E9EF", consoleText: "#4C4F69"),
        EditorTheme(name: "Forest", fontName: "SF Mono", fontSize: 13, background: "#1B2B23", foreground: "#D8E6DF", selection: "#2E473B", currentLine: "#23372D",
                    tokens: ["keyword": "#87D37C", "comment": "#5D7D6D", "docComment": "#A2DED0", "string": "#F5D76E", "number": "#E67E22",
                             "preprocessor": "#2ECC71", "attribute": "#4ECDC4", "typeName": "#4ECDC4"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#14211B", consoleText: "#D8E6DF"),
        EditorTheme(name: "Cobalt", fontName: "SF Mono", fontSize: 13, background: "#193549", foreground: "#E1EFFF", selection: "#1F4662", currentLine: "#203E56",
                    tokens: ["keyword": "#FF9D00", "comment": "#0088FF", "docComment": "#3AD900", "string": "#3AD900", "number": "#FF628C",
                             "preprocessor": "#FFC600", "attribute": "#80FFBB", "typeName": "#80FFBB"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#122738", consoleText: "#E1EFFF"),
        EditorTheme(name: "SwiftCode Paper", fontName: "", fontSize: 13, background: "#FBF8F1", foreground: "#2B2A27", selection: "#E3DCC8", currentLine: "#F2ECDD",
                    tokens: ["keyword": "#8A2D5E", "comment": "#8C8778", "docComment": "#5E7A3A", "string": "#A3471B", "number": "#2F5E9E",
                             "preprocessor": "#9A5B12", "attribute": "#6E5A2E", "typeName": "#4E3F94"],
                    consoleFontName: "", consoleFontSize: 11, consoleBackground: "#FBF8F1", consoleText: "#2B2A27"),
        EditorTheme(name: "SwiftCode Dusk", fontName: "", fontSize: 12, background: "#1E2128", foreground: "#D8DCE3", selection: "#3A4252", currentLine: "#262A33",
                    tokens: ["keyword": "#E58AB8", "comment": "#7A8291", "docComment": "#93B87A", "string": "#E9A37A", "number": "#8DB4F0",
                             "preprocessor": "#E2B86B", "attribute": "#C9A97A", "typeName": "#B9A6F2"],
                    consoleFontName: "", consoleFontSize: 11, consoleBackground: "#1A1C22", consoleText: "#D8DCE3"),
        EditorTheme(name: "SwiftCode High Contrast", fontName: "", fontSize: 13, background: "#000000", foreground: "#FFFFFF", selection: "#264F9E", currentLine: "#1A1A1A",
                    tokens: ["keyword": "#FF6FB5", "comment": "#B0B0B0", "docComment": "#7CFC7C", "string": "#FFB070", "number": "#7FD4FF",
                             "preprocessor": "#FFD75E", "attribute": "#E8C890", "typeName": "#C8A8FF"],
                    consoleFontName: "", consoleFontSize: 12, consoleBackground: "#000000", consoleText: "#FFFFFF"),
        EditorTheme(name: "GitHub Dark", fontName: "SF Mono", fontSize: 13, background: "#0D1117", foreground: "#E6EDF3", selection: "#264F78", currentLine: "#161B22",
                    tokens: ["keyword": "#FF7B72", "comment": "#8B949E", "docComment": "#A5D6FF", "string": "#A5D6FF", "number": "#79C0FF",
                             "preprocessor": "#FF7B72", "attribute": "#D2A8FF", "typeName": "#79C0FF"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#161B22", consoleText: "#E6EDF3"),
        EditorTheme(name: "Gruvbox Light", fontName: "SF Mono", fontSize: 13, background: "#FBF1C7", foreground: "#3C3836", selection: "#D5C4A1", currentLine: "#F2E5BC",
                    tokens: ["keyword": "#9D0006", "comment": "#928374", "docComment": "#79740E", "string": "#79740E", "number": "#8F3F71",
                             "preprocessor": "#AF3A03", "attribute": "#427B58", "typeName": "#076678"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#EBDBB2", consoleText: "#3C3836"),
        EditorTheme(name: "One Light", fontName: "SF Mono", fontSize: 13, background: "#FAFAFA", foreground: "#383A42", selection: "#D3E0F0", currentLine: "#F0F0F0",
                    tokens: ["keyword": "#A626A4", "comment": "#A0A1A7", "docComment": "#50A14F", "string": "#50A14F", "number": "#B76B01",
                             "preprocessor": "#A626A4", "attribute": "#4078F2", "typeName": "#C18401"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#F0F0F0", consoleText: "#383A42"),
        EditorTheme(name: "Ayu Light", fontName: "SF Mono", fontSize: 13, background: "#FAFAFA", foreground: "#5C6773", selection: "#FFE8C2", currentLine: "#F0F1F2",
                    tokens: ["keyword": "#F29718", "comment": "#ABB0BF", "docComment": "#86B300", "string": "#86B300", "number": "#FF9940",
                             "preprocessor": "#F29718", "attribute": "#399EE6", "typeName": "#399EE6"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#F3F4F5", consoleText: "#5C6773"),
        EditorTheme(name: "Ayu Mirage", fontName: "SF Mono", fontSize: 13, background: "#1F2430", foreground: "#CBCCC6", selection: "#33415E", currentLine: "#232834",
                    tokens: ["keyword": "#FFA759", "comment": "#5C6773", "docComment": "#BAE67E", "string": "#BAE67E", "number": "#FFD580",
                             "preprocessor": "#FFA759", "attribute": "#73D0FF", "typeName": "#73D0FF"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#1A1F2B", consoleText: "#CBCCC6"),
        EditorTheme(name: "Tokyo Night Day", fontName: "SF Mono", fontSize: 13, background: "#E1E2E7", foreground: "#3760BF", selection: "#C0CAF5", currentLine: "#DDE0E8",
                    tokens: ["keyword": "#9854F1", "comment": "#848CB5", "docComment": "#587539", "string": "#587539", "number": "#B15C00",
                             "preprocessor": "#9854F1", "attribute": "#2E7DE9", "typeName": "#2E7DE9"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#D8DAE2", consoleText: "#3760BF"),
        EditorTheme(name: "Rosé Pine Moon", fontName: "SF Mono", fontSize: 13, background: "#232136", foreground: "#E0DEF4", selection: "#44415A", currentLine: "#2A273F",
                    tokens: ["keyword": "#C4A7E7", "comment": "#6E6A86", "docComment": "#9CCFD8", "string": "#9CCFD8", "number": "#F6C177",
                             "preprocessor": "#EA9A97", "attribute": "#EBBCBA", "typeName": "#9CCFD8"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#1F1D2E", consoleText: "#E0DEF4"),
        EditorTheme(name: "Rosé Pine Dawn", fontName: "SF Mono", fontSize: 13, background: "#FAF4ED", foreground: "#575279", selection: "#E5D5CB", currentLine: "#F2E9E1",
                    tokens: ["keyword": "#907AA9", "comment": "#9893A5", "docComment": "#56949F", "string": "#56949F", "number": "#EA9D34",
                             "preprocessor": "#D7827E", "attribute": "#D7827E", "typeName": "#286983"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#F2E9E1", consoleText: "#575279"),
        EditorTheme(name: "Catppuccin Frappé", fontName: "SF Mono", fontSize: 13, background: "#303446", foreground: "#C6D0F5", selection: "#51576D", currentLine: "#414559",
                    tokens: ["keyword": "#CA9EE6", "comment": "#737994", "docComment": "#A6D189", "string": "#A6D189", "number": "#EF9F76",
                             "preprocessor": "#F4B8E4", "attribute": "#8CAAEE", "typeName": "#85C1DC"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#292C3C", consoleText: "#C6D0F5"),
        EditorTheme(name: "Catppuccin Macchiato", fontName: "SF Mono", fontSize: 13, background: "#24273A", foreground: "#CAD3F5", selection: "#494D64", currentLine: "#363A4F",
                    tokens: ["keyword": "#C6A0F6", "comment": "#5B6078", "docComment": "#A6DA95", "string": "#A6DA95", "number": "#F5A97F",
                             "preprocessor": "#F5BDE6", "attribute": "#8AADF4", "typeName": "#8BD5CA"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#1E2030", consoleText: "#CAD3F5"),
        EditorTheme(name: "GitHub Dark Dimmed", fontName: "SF Mono", fontSize: 13, background: "#22272E", foreground: "#ADBAC7", selection: "#2D333B", currentLine: "#2A2F36",
                    tokens: ["keyword": "#F47067", "comment": "#768390", "docComment": "#96D0FF", "string": "#96D0FF", "number": "#F69D50",
                             "preprocessor": "#F69D50", "attribute": "#D2A8FF", "typeName": "#F47067"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#1C2127", consoleText: "#ADBAC7"),
        EditorTheme(name: "GitHub Light High Contrast", fontName: "SF Mono", fontSize: 13, background: "#FFFFFF", foreground: "#000000", selection: "#B6D4FE", currentLine: "#F6F8FA",
                    tokens: ["keyword": "#8250DF", "comment": "#57606A", "docComment": "#0969DA", "string": "#0A3069", "number": "#0550AE",
                             "preprocessor": "#CF222E", "attribute": "#0969DA", "typeName": "#8250DF"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#F6F8FA", consoleText: "#000000"),
        EditorTheme(name: "Tokyo Night Storm", fontName: "SF Mono", fontSize: 13, background: "#24283B", foreground: "#C0CAF5", selection: "#3B4261", currentLine: "#2F344D",
                    tokens: ["keyword": "#BB9AF7", "comment": "#545C7E", "docComment": "#9ECE6A", "string": "#9ECE6A", "number": "#FF9E64",
                             "preprocessor": "#7DCFFF", "attribute": "#E0AF68", "typeName": "#7AA2F7"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#1F2335", consoleText: "#C0CAF5"),
        EditorTheme(name: "One Dark Pro", fontName: "SF Mono", fontSize: 13, background: "#282C34", foreground: "#ABB2BF", selection: "#3E4451", currentLine: "#2C313A",
                    tokens: ["keyword": "#C678DD", "comment": "#7F848E", "docComment": "#98C379", "string": "#98C379", "number": "#D19A66",
                             "preprocessor": "#E5C07B", "attribute": "#61AFEF", "typeName": "#E06C75"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#21252B", consoleText: "#ABB2BF"),
        EditorTheme(name: "Nightfox", fontName: "SF Mono", fontSize: 13, background: "#192330", foreground: "#D1D6C9", selection: "#2D3B4D", currentLine: "#212B3A",
                    tokens: ["keyword": "#C793C9", "comment": "#566276", "docComment": "#C2D94C", "string": "#99C794", "number": "#E0AF68",
                             "preprocessor": "#FF9E64", "attribute": "#FFA07A", "typeName": "#7AA2F7"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#141C27", consoleText: "#D1D6C9"),
        EditorTheme(name: "Oceanic Next", fontName: "SF Mono", fontSize: 13, background: "#1B2B34", foreground: "#D8DEE9", selection: "#2A3F4D", currentLine: "#223440",
                    tokens: ["keyword": "#B48EAD", "comment": "#65737E", "docComment": "#8FA1B3", "string": "#99C794", "number": "#D08770",
                             "preprocessor": "#EC5f67", "attribute": "#EC5f67", "typeName": "#8FA1B3"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#14232B", consoleText: "#D8DEE9"),
        EditorTheme(name: "Poimandres", fontName: "SF Mono", fontSize: 13, background: "#1B1E28", foreground: "#CDD6F4", selection: "#3A3F55", currentLine: "#262B3A",
                    tokens: ["keyword": "#C792EA", "comment": "#51576D", "docComment": "#C3E88D", "string": "#C3E88D", "number": "#F5C2E7",
                             "preprocessor": "#F5C2E7", "attribute": "#89B4FA", "typeName": "#89B4FA"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#161821", consoleText: "#CDD6F4"),
        EditorTheme(name: "Dark+", fontName: "SF Mono", fontSize: 13, background: "#1E1E1E", foreground: "#D4D4D4", selection: "#264F78", currentLine: "#2A2D2E",
                    tokens: ["keyword": "#569CD6", "comment": "#6A9955", "docComment": "#6A9955", "string": "#CE9178", "number": "#B5CEA8",
                             "preprocessor": "#C586C0", "attribute": "#9CDCFE", "typeName": "#4EC9B0"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#181818", consoleText: "#D4D4D4"),
        EditorTheme(name: "Andromeeda", fontName: "SF Mono", fontSize: 13, background: "#232A2E", foreground: "#D6DBE5", selection: "#38444B", currentLine: "#2B343A",
                    tokens: ["keyword": "#F670D0", "comment": "#7A8699", "docComment": "#8BBF7E", "string": "#99C794", "number": "#F78C6C",
                             "preprocessor": "#FFCB6B", "attribute": "#7FDBCA", "typeName": "#82AAFF"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#1C2226", consoleText: "#D6DBE5"),
        EditorTheme(name: "Aurora", fontName: "SF Mono", fontSize: 13, background: "#1E1B24", foreground: "#E6E6E6", selection: "#3A3345", currentLine: "#282230",
                    tokens: ["keyword": "#FFB86C", "comment": "#7E6F8E", "docComment": "#A8CC7C", "string": "#A8CC7C", "number": "#FFCB6B",
                             "preprocessor": "#F78C6C", "attribute": "#7FDBCA", "typeName": "#82AAFF"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#181520", consoleText: "#E6E6E6"),
        EditorTheme(name: "Buffer", fontName: "SF Mono", fontSize: 13, background: "#282A2B", foreground: "#EFF1F5", selection: "#3A4048", currentLine: "#2F3338",
                    tokens: ["keyword": "#CC99CD", "comment": "#505862", "docComment": "#65C184", "string": "#65C184", "number": "#F99157",
                             "preprocessor": "#F99157", "attribute": "#67B7A4", "typeName": "#67B7A4"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#1F2122", consoleText: "#EFF1F5"),
        EditorTheme(name: "Brogrammer", fontName: "SF Mono", fontSize: 13, background: "#0C101C", foreground: "#FFFFFF", selection: "#1B2740", currentLine: "#10182B",
                    tokens: ["keyword": "#C586C0", "comment": "#6A9955", "docComment": "#6A9955", "string": "#CE9178", "number": "#D7BA7D",
                             "preprocessor": "#C586C0", "attribute": "#9CDCFE", "typeName": "#4EC9B0"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#080B14", consoleText: "#FFFFFF"),
        EditorTheme(name: "Cobalt2", fontName: "SF Mono", fontSize: 13, background: "#193549", foreground: "#FFFFFF", selection: "#1F4662", currentLine: "#1C3A50",
                    tokens: ["keyword": "#FF9E64", "comment": "#7587A6", "docComment": "#80FFBB", "string": "#9CCC65", "number": "#FFC600",
                             "preprocessor": "#FFC600", "attribute": "#FF9E64", "typeName": "#80FFBB"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#122738", consoleText: "#FFFFFF"),
        EditorTheme(name: "Darkside", fontName: "SF Mono", fontSize: 13, background: "#282A36", foreground: "#FFFFFF", selection: "#44475A", currentLine: "#343746",
                    tokens: ["keyword": "#FF757F", "comment": "#6272A4", "docComment": "#50FA7B", "string": "#F1FA8C", "number": "#BD93F9",
                             "preprocessor": "#FFB86C", "attribute": "#8BE9FD", "typeName": "#8BE9FD"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#21222C", consoleText: "#FFFFFF"),
        EditorTheme(name: "Edge", fontName: "SF Mono", fontSize: 13, background: "#1A1B22", foreground: "#ABB2BF", selection: "#2C313C", currentLine: "#22242C",
                    tokens: ["keyword": "#C678DD", "comment": "#5C6370", "docComment": "#98C379", "string": "#98C379", "number": "#D19A66",
                             "preprocessor": "#E5C07B", "attribute": "#61AFEF", "typeName": "#56B6C2"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#141519", consoleText: "#ABB2BF"),
        EditorTheme(name: "Flexoki", fontName: "SF Mono", fontSize: 13, background: "#100F0F", foreground: "#D0C8C0", selection: "#34302B", currentLine: "#1C1B19",
                    tokens: ["keyword": "#E67E80", "comment": "#6E6A60", "docComment": "#A7C080", "string": "#A7C080", "number": "#D0BF8F",
                             "preprocessor": "#DFA000", "attribute": "#7FA6C9", "typeName": "#7FA6C9"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#0A0909", consoleText: "#D0C8C0"),
        EditorTheme(name: "GitHub Light", fontName: "SF Mono", fontSize: 13, background: "#FFFFFF", foreground: "#24292F", selection: "#B6D4FE", currentLine: "#F6F8FA",
                    tokens: ["keyword": "#8250DF", "comment": "#6E7781", "docComment": "#0969DA", "string": "#0A3069", "number": "#0550AE",
                             "preprocessor": "#CF222E", "attribute": "#0969DA", "typeName": "#953800"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#F6F8FA", consoleText: "#24292F"),
        EditorTheme(name: "Hacker", fontName: "SF Mono", fontSize: 13, background: "#000000", foreground: "#FFFFFF", selection: "#003300", currentLine: "#0A0A0A",
                    tokens: ["keyword": "#00FF00", "comment": "#555555", "docComment": "#00FF00", "string": "#00FF00", "number": "#00FFFF",
                             "preprocessor": "#00FF00", "attribute": "#FFFFFF", "typeName": "#00FF00"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#000000", consoleText: "#00FF00"),
        EditorTheme(name: "IR Black", fontName: "SF Mono", fontSize: 13, background: "#000000", foreground: "#F8F8F8", selection: "#264F78", currentLine: "#141414",
                    tokens: ["keyword": "#569CD6", "comment": "#6A9955", "docComment": "#6A9955", "string": "#CE9178", "number": "#B5CEA8",
                             "preprocessor": "#C586C0", "attribute": "#9CDCFE", "typeName": "#4EC9B0"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#000000", consoleText: "#F8F8F8"),
        EditorTheme(name: "Jack", fontName: "SF Mono", fontSize: 13, background: "#000000", foreground: "#FFFFFF", selection: "#333333", currentLine: "#0D0D0D",
                    tokens: ["keyword": "#FFFFFF", "comment": "#FF0000", "docComment": "#FF0000", "string": "#FFFF00", "number": "#FFFFFF",
                             "preprocessor": "#FFFFFF", "attribute": "#00FFFF", "typeName": "#FFFFFF"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#000000", consoleText: "#FFFFFF"),
        EditorTheme(name: "Kale", fontName: "SF Mono", fontSize: 13, background: "#031A16", foreground: "#E4F0EA", selection: "#0E3A30", currentLine: "#07241E",
                    tokens: ["keyword": "#7FDBCA", "comment": "#406353", "docComment": "#A8CC7C", "string": "#FDE047", "number": "#FB8C00",
                             "preprocessor": "#F78C6C", "attribute": "#82AAFF", "typeName": "#82AAFF"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#02120E", consoleText: "#E4F0EA"),
        EditorTheme(name: "Mac Classic", fontName: "SF Mono", fontSize: 13, background: "#FFFFFF", foreground: "#000000", selection: "#B4D8FD", currentLine: "#F2F4F7",
                    tokens: ["keyword": "#0000FF", "comment": "#008000", "docComment": "#008000", "string": "#FF0000", "number": "#FF00FF",
                             "preprocessor": "#000080", "attribute": "#800080", "typeName": "#000080"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#FFFFFF", consoleText: "#000000"),
        EditorTheme(name: "Mariana", fontName: "SF Mono", fontSize: 13, background: "#0F1419", foreground: "#D8DEE9", selection: "#1F2B38", currentLine: "#161D24",
                    tokens: ["keyword": "#C792EA", "comment": "#546E7A", "docComment": "#C3E88D", "string": "#C3E88D", "number": "#F78C6C",
                             "preprocessor": "#FFCB6B", "attribute": "#7FDBCA", "typeName": "#82AAFF"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#0A0E13", consoleText: "#D8DEE9"),
        EditorTheme(name: "Metropolis", fontName: "SF Mono", fontSize: 13, background: "#2B2B2B", foreground: "#E8E8E8", selection: "#404040", currentLine: "#333333",
                    tokens: ["keyword": "#F92672", "comment": "#75715E", "docComment": "#A6E22E", "string": "#A6E22E", "number": "#AE81FF",
                             "preprocessor": "#FD971F", "attribute": "#66D9EF", "typeName": "#66D9EF"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#202020", consoleText: "#E8E8E8"),
        EditorTheme(name: "Mirage", fontName: "SF Mono", fontSize: 13, background: "#000000", foreground: "#F7EBC6", selection: "#333300", currentLine: "#0D0D0D",
                    tokens: ["keyword": "#FFB000", "comment": "#AEAEAE", "docComment": "#95FFA4", "string": "#95FFA4", "number": "#FD971F",
                             "preprocessor": "#FFB000", "attribute": "#66D9EF", "typeName": "#66D9EF"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#000000", consoleText: "#F7EBC6"),
        EditorTheme(name: "Mojave", fontName: "SF Mono", fontSize: 13, background: "#1F222D", foreground: "#E6E6E6", selection: "#333A4D", currentLine: "#262B38",
                    tokens: ["keyword": "#C792EA", "comment": "#5C6370", "docComment": "#C3E88D", "string": "#C3E88D", "number": "#F78C6C",
                             "preprocessor": "#FFCB6B", "attribute": "#7FDBCA", "typeName": "#82AAFF"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#181B24", consoleText: "#E6E6E6"),
        EditorTheme(name: "Palenight", fontName: "SF Mono", fontSize: 13, background: "#292D3E", foreground: "#A6ACCD", selection: "#3B4057", currentLine: "#2F3348",
                    tokens: ["keyword": "#C792EA", "comment": "#676E95", "docComment": "#C3E88D", "string": "#C3E88D", "number": "#FFCB6B",
                             "preprocessor": "#F78C6C", "attribute": "#82AAFF", "typeName": "#82AAFF"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#222636", consoleText: "#A6ACCD"),
        EditorTheme(name: "Primer", fontName: "SF Mono", fontSize: 13, background: "#FFFFFF", foreground: "#24292F", selection: "#B6D4FE", currentLine: "#F6F8FA",
                    tokens: ["keyword": "#8250DF", "comment": "#57606A", "docComment": "#0969DA", "string": "#0A3069", "number": "#0550AE",
                             "preprocessor": "#CF222E", "attribute": "#953800", "typeName": "#953800"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#F6F8FA", consoleText: "#24292F"),
        EditorTheme(name: "Quietlight", fontName: "SF Mono", fontSize: 13, background: "#FFFFFF", foreground: "#000000", selection: "#B6D4FE", currentLine: "#F2F4F7",
                    tokens: ["keyword": "#0000FF", "comment": "#008000", "docComment": "#008000", "string": "#DD1144", "number": "#098658",
                             "preprocessor": "#000080", "attribute": "#000080", "typeName": "#000080"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#F6F8FA", consoleText: "#000000"),
        EditorTheme(name: "Red", fontName: "SF Mono", fontSize: 13, background: "#38080A", foreground: "#F8F8F8", selection: "#5A1416", currentLine: "#421013",
                    tokens: ["keyword": "#FF7583", "comment": "#888888", "docComment": "#A9DC76", "string": "#FC6A5D", "number": "#D0BF69",
                             "preprocessor": "#FF7583", "attribute": "#5DD8FF", "typeName": "#5DD8FF"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#2A0607", consoleText: "#F8F8F8"),
        EditorTheme(name: "Sublime", fontName: "SF Mono", fontSize: 13, background: "#282B2B", foreground: "#E8E8E8", selection: "#414141", currentLine: "#313434",
                    tokens: ["keyword": "#CC99CD", "comment": "#65737E", "docComment": "#8EC07C", "string": "#8EC07C", "number": "#D19A66",
                             "preprocessor": "#56B6C2", "attribute": "#56B6C2", "typeName": "#56B6C2"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#1F2121", consoleText: "#E8E8E8"),
        EditorTheme(name: "Twilight", fontName: "SF Mono", fontSize: 13, background: "#131313", foreground: "#F8F8F2", selection: "#3E3D32", currentLine: "#1E1E1E",
                    tokens: ["keyword": "#F92672", "comment": "#75715E", "docComment": "#A6E22E", "string": "#A6E22E", "number": "#AE81FF",
                             "preprocessor": "#FD971F", "attribute": "#66D9EF", "typeName": "#66D9EF"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#0D0D0D", consoleText: "#F8F8F2"),
        EditorTheme(name: "Verminal", fontName: "SF Mono", fontSize: 13, background: "#35242F", foreground: "#FFFFFF", selection: "#4D3644", currentLine: "#3D2A38",
                    tokens: ["keyword": "#FFB000", "comment": "#8A7F8D", "docComment": "#A9DC76", "string": "#FC6A5D", "number": "#AE81FF",
                             "preprocessor": "#FFB000", "attribute": "#66D9EF", "typeName": "#66D9EF"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#2A1D26", consoleText: "#FFFFFF"),
        EditorTheme(name: "VS Code Light+", fontName: "SF Mono", fontSize: 13, background: "#FFFFFF", foreground: "#000000", selection: "#ADD6FF", currentLine: "#F8F8F8",
                    tokens: ["keyword": "#0000FF", "comment": "#008000", "docComment": "#008000", "string": "#A31515", "number": "#098658",
                             "preprocessor": "#AF00DB", "attribute": "#FF0000", "typeName": "#267F99"],
                    consoleFontName: "SF Mono", consoleFontSize: 11, consoleBackground: "#F3F3F3", consoleText: "#000000"),
    ]
}

@MainActor
public enum KeyBindings {
    public struct Entry: Equatable, Sendable {
        public var id: String
        public var title: String
        public var menu: String
        public var command: MenuCommand
        public var customized: Bool
    }

    static func id(_ c: MenuCommand) -> String { "\(c.action)#\(c.tag)" }

    public static func entries(_ prefs: Preferences = .shared, includingUnavailable: Bool = false) -> [Entry] {
        let overrides = prefs.keyBindingOverrides
        var out: [Entry] = []
        func walk(_ items: [MenuItemSpec], _ path: String) {
            for i in items {
                switch i {
                case .separator, .label: break
                case .submenu(let t, let sub): walk(sub, path + " ▸ " + t)
                case .command(var c) where c.isAvailable || includingUnavailable:
                    let id = id(c)
                    if let o = overrides[id] { c.key = o.key; c.modifiers = o.key.isEmpty ? [] : o.mods }
                    out.append(Entry(id: id, title: c.title, menu: path, command: c, customized: overrides[id] != nil))
                case .command: break
                }
            }
        }
        for (menu, items) in CommandTable.menus { walk(items, menu) }
        return out
    }

    public static func search(_ q: String, _ prefs: Preferences = .shared) -> [Entry] {
        let t = q.lowercased()
        return entries(prefs).filter { t.isEmpty || $0.title.lowercased().contains(t) || $0.menu.lowercased().contains(t) || $0.command.shortcutText.lowercased().contains(t) }
    }

    public static func conflicts(key: String, modifiers: MenuCommand.Modifiers, excluding id: String, _ prefs: Preferences = .shared) -> [Entry] {
        guard !key.isEmpty else { return [] }
        let wanted = Shortcut.canonical(key: key, modifiers: modifiers)
        var seen = Set<String>()
        return entries(prefs, includingUnavailable: true).filter {
            $0.id != id && $0.command.canonicalShortcut == wanted && seen.insert($0.id).inserted
        }
    }

    @discardableResult
    public static func set(_ id: String, key: String, modifiers: MenuCommand.Modifiers, _ prefs: Preferences = .shared) -> [Entry] {
        let c = conflicts(key: key, modifiers: modifiers, excluding: id, prefs)
        guard c.isEmpty else { return c }
        var o = prefs.keyBindingOverrides
        o[id] = Preferences.Shortcut(key: key, modifiers: key.isEmpty ? [] : modifiers)
        prefs.keyBindingOverrides = o
        return []
    }

    public static func reset(_ id: String, _ prefs: Preferences = .shared) {
        var o = prefs.keyBindingOverrides
        o[id] = nil
        prefs.keyBindingOverrides = o
    }

    public static func effective(_ c: MenuCommand, _ prefs: Preferences = .shared) -> MenuCommand {
        guard let o = prefs.keyBindingOverrides[id(c)] else { return c }
        var c = c
        c.key = o.key
        c.modifiers = o.key.isEmpty ? [] : o.mods
        return c
    }
}

public struct ThemeColor: Equatable, Hashable, Sendable {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8
    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public init?(hex: String?) {
        guard var h = hex?.trimmingCharacters(in: .whitespaces), !h.isEmpty else { return nil }
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let v = UInt32(h, radix: 16) else { return nil }
        self.init(red: UInt8(v >> 16 & 0xFF), green: UInt8(v >> 8 & 0xFF), blue: UInt8(v & 0xFF))
    }

    public var hex: String { String(format: "#%02X%02X%02X", Int(red), Int(green), Int(blue)) }

    public var redFraction: Double { Double(red) / 255 }
    public var greenFraction: Double { Double(green) / 255 }
    public var blueFraction: Double { Double(blue) / 255 }
}
