import Foundation

public struct LanguageServerDefinition: Sendable, Hashable {
    public var languageID: String
    public var sourceLanguage: SourceLanguage?
    public var displayName: String
    public var binaryNames: [String]
    public var arguments: [String]
    public var installGuidance: String

    public init(languageID: String, sourceLanguage: SourceLanguage? = nil, displayName: String,
                binaryNames: [String], arguments: [String] = [], installGuidance: String) {
        self.languageID = languageID
        self.sourceLanguage = sourceLanguage
        self.displayName = displayName
        self.binaryNames = binaryNames
        self.arguments = arguments
        self.installGuidance = installGuidance
    }
}

public enum LanguageServerDefinitions {
    public static let all: [LanguageServerDefinition] = [
        LanguageServerDefinition(
            languageID: "swift", sourceLanguage: .swift, displayName: "sourcekit-lsp",
            binaryNames: ["sourcekit-lsp"],
            installGuidance: "sourcekit-lsp ships with the Xcode Command Line Tools and Swift toolchains. Install Xcode or a Swift toolchain and make sure sourcekit-lsp is on PATH (xcrun -f sourcekit-lsp)."),
        LanguageServerDefinition(
            languageID: "c", sourceLanguage: .c, displayName: "clangd",
            binaryNames: ["clangd"],
            installGuidance: "Install clangd with your toolchain: brew install llvm on macOS, or apt install clangd on Linux, then put clangd on PATH."),
        LanguageServerDefinition(
            languageID: "cpp", sourceLanguage: .cpp, displayName: "clangd",
            binaryNames: ["clangd"],
            installGuidance: "Install clangd with your toolchain: brew install llvm on macOS, or apt install clangd on Linux, then put clangd on PATH."),
        LanguageServerDefinition(
            languageID: "objective-c", sourceLanguage: .objectiveC, displayName: "clangd",
            binaryNames: ["clangd"],
            installGuidance: "Install clangd with your toolchain: brew install llvm on macOS, then put clangd on PATH."),
        LanguageServerDefinition(
            languageID: "objective-cpp", sourceLanguage: .objectiveCpp, displayName: "clangd",
            binaryNames: ["clangd"],
            installGuidance: "Install clangd with your toolchain: brew install llvm on macOS, then put clangd on PATH."),
        LanguageServerDefinition(
            languageID: "rust", sourceLanguage: .rust, displayName: "rust-analyzer",
            binaryNames: ["rust-analyzer"],
            installGuidance: "Install rust-analyzer with rustup component add rust-analyzer, or brew install rust-analyzer, then put rust-analyzer on PATH."),
        LanguageServerDefinition(
            languageID: "go", sourceLanguage: .go, displayName: "gopls",
            binaryNames: ["gopls"],
            installGuidance: "Install gopls with go install golang.org/x/tools/gopls@latest, then put $GOPATH/bin on PATH."),
        LanguageServerDefinition(
            languageID: "java", sourceLanguage: .java, displayName: "eclipse.jdt.ls",
            binaryNames: ["jdtls"],
            installGuidance: "Install eclipse.jdt.ls and put its jdtls launcher on PATH (https://github.com/eclipse-jdtls/eclipse.jdt.ls)."),
        LanguageServerDefinition(
            languageID: "csharp", sourceLanguage: .csharp, displayName: "OmniSharp",
            binaryNames: ["omnisharp", "OmniSharp"], arguments: ["-lsp"],
            installGuidance: "Install OmniSharp with brew install omnisharp on macOS, or download a release from https://github.com/OmniSharp/omnisharp-roslyn."),
        LanguageServerDefinition(
            languageID: "kotlin", sourceLanguage: .kotlin, displayName: "kotlin-language-server",
            binaryNames: ["kotlin-language-server"],
            installGuidance: "Install kotlin-language-server with brew install kotlin-language-server on macOS, or download a release from https://github.com/fwcd/kotlin-language-server."),
        LanguageServerDefinition(
            languageID: "javascript", displayName: "typescript-language-server",
            binaryNames: ["typescript-language-server"], arguments: ["--stdio"],
            installGuidance: "Install typescript-language-server with npm install -g typescript-language-server typescript."),
        LanguageServerDefinition(
            languageID: "typescript", displayName: "typescript-language-server",
            binaryNames: ["typescript-language-server"], arguments: ["--stdio"],
            installGuidance: "Install typescript-language-server with npm install -g typescript-language-server typescript."),
        LanguageServerDefinition(
            languageID: "python", displayName: "pyright",
            binaryNames: ["pyright-langserver", "basedpyright-langserver"], arguments: ["--stdio"],
            installGuidance: "Install pyright with npm install -g pyright, or pip install basedpyright."),
        LanguageServerDefinition(
            languageID: "lua", displayName: "lua-language-server",
            binaryNames: ["lua-language-server"],
            installGuidance: "Install lua-language-server with brew install lua-language-server on macOS, or download a release from https://github.com/LuaLS/lua-language-server."),
        LanguageServerDefinition(
            languageID: "nim", displayName: "nimlsp",
            binaryNames: ["nimlsp"],
            installGuidance: "Install nimlsp with nimble install nimlsp, then put nimlsp on PATH."),
        LanguageServerDefinition(
            languageID: "d", displayName: "serve-d",
            binaryNames: ["serve-d"],
            installGuidance: "Install serve-d with dub fetch serve-d, or download a release from https://github.com/Pure-D/serve-d."),
    ]

    public static func definition(for language: SourceLanguage) -> LanguageServerDefinition? {
        all.first { $0.sourceLanguage == language }
    }

    public static func definition(languageID: String) -> LanguageServerDefinition? {
        all.first { $0.languageID == languageID }
    }

    public static func locateBinary(for definition: LanguageServerDefinition,
                                    environment: [String: String] = ProcessInfo.processInfo.environment) -> String? {
        for name in definition.binaryNames {
            if name.contains("/") {
                if FileManager.default.isExecutableFile(atPath: name) { return name }
                continue
            }
            if let found = locateOnPath(name, environment: environment) { return found }
        }
        return nil
    }

    public static func locateOnPath(_ name: String,
                                   environment: [String: String] = ProcessInfo.processInfo.environment) -> String? {
        guard let pathValue = environment["PATH"], !pathValue.isEmpty else { return nil }
        for directory in pathValue.components(separatedBy: ":") {
            guard !directory.isEmpty else { continue }
            let candidate = (directory as NSString).appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: candidate) { return candidate }
        }
        return nil
    }

    public static func missingBinaryMessage(for definition: LanguageServerDefinition) -> String {
        let names = definition.binaryNames.joined(separator: " or ")
        return "No language server found for \(definition.displayName) (looked for \(names) on PATH). \(definition.installGuidance)"
    }
}
