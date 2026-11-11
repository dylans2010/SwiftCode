import Foundation

public struct GoBackend: AssembleBackend {
    public init() {}

    public var id: String { "go" }
    public var displayName: String { "Go" }
    public var kind: BackendKind { .native }
    public var buildMode: BackendBuildMode { .library }
    public var sourceExtensions: Set<String> { ["go"] }

    public func availability(configuration: BuildConfiguration) -> BackendAvailability {
        guard let found = Self.locateGo() else {
            return .unavailable(
                reason: "No Go toolchain was found.",
                installGuidance: "Install Go from https://go.dev/dl (or brew install go) and make sure go is on PATH, then try again.")
        }
        if ClangBackend.locateCompiler() == nil {
            return .unavailable(
                reason: "Go builds a shared library through cgo, which needs a C compiler.",
                installGuidance: "Install Xcode or the Xcode Command Line Tools (xcode-select --install) on macOS, or install clang or gcc on Linux, and try again.")
        }
        return .available(toolPath: found, version: BackendToolDiscovery.toolVersion(found, arguments: ["version"]))
    }

    public static func locateGo() -> String? {
        BackendToolDiscovery.locate(
            xcrunTool: nil,
            fixedPaths: ["/usr/local/go/bin/go", "/opt/homebrew/bin/go", "~/.local/bin/go"],
            pathNames: ["go"])
    }

    public func prepareProject(projectRoot: URL, configuration: BuildConfiguration) throws {
        let sourcesDir = projectRoot.appendingPathComponent("Sources", isDirectory: true)
        let goModURL = sourcesDir.appendingPathComponent("go.mod")
        guard !FileManager.default.fileExists(atPath: goModURL.path) else { return }
        let module = SwiftBackend.moduleName(configuration: configuration).lowercased()
        try "module \(module)\n\ngo 1.21\n".write(to: goModURL, atomically: true, encoding: .utf8)
    }

    public func libraryWorkingDirectory(projectRoot: URL, configuration: BuildConfiguration) -> URL? {
        projectRoot.appendingPathComponent("Sources", isDirectory: true)
    }

    public func libraryEnvironment(configuration: BuildConfiguration) -> [String: String] {
        ["CGO_ENABLED": "1", "GOTOOLCHAIN": "local"]
    }

    public func libraryArguments(sources: [URL], output: URL, projectRoot: URL, configuration: BuildConfiguration) -> [String] {
        var args = ["build", "-buildmode=c-shared", "-o", output.path, "."]
        args.append(contentsOf: configuration.perBackendFlags["go"] ?? [])
        return args
    }

    public func parseDiagnostics(_ text: String, projectRoot: URL) -> [AssemblyDiagnostic] {
        var diagnostics: [AssemblyDiagnostic] = []
        let pattern = #"^(.+?):(\d+):(\d+):\s+(.*)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return diagnostics }
        for rawLine in text.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            guard let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                  match.numberOfRanges == 5,
                  let fileRange = Range(match.range(at: 1), in: line),
                  let lineRange = Range(match.range(at: 2), in: line),
                  let colRange = Range(match.range(at: 3), in: line),
                  let msgRange = Range(match.range(at: 4), in: line) else { continue }
            var file = String(line[fileRange])
            if file.hasPrefix(projectRoot.path) {
                file = String(file.dropFirst(projectRoot.path.count + 1))
            }
            diagnostics.append(AssemblyDiagnostic(
                severity: .error,
                message: String(line[msgRange]),
                file: file,
                line: Int(line[lineRange]),
                column: Int(line[colRange]),
                origin: .userCode,
                rawText: rawLine))
        }
        return diagnostics
    }
}
