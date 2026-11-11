import Foundation

public struct NimBackend: AssembleBackend {
    public init() {}

    public var id: String { "nim" }
    public var displayName: String { "Nim" }
    public var kind: BackendKind { .native }
    public var buildMode: BackendBuildMode { .library }
    public var sourceExtensions: Set<String> { ["nim"] }

    public func availability(configuration: BuildConfiguration) -> BackendAvailability {
        guard let found = Self.locateNim() else {
            return .unavailable(
                reason: "No Nim compiler was found.",
                installGuidance: "Install Nim from https://nim-lang.org/install.html (or brew install nim, or choosenim) and make sure nim is on PATH, then try again.")
        }
        if ClangBackend.locateCompiler() == nil {
            return .unavailable(
                reason: "Nim compiles through a C compiler, which was not found.",
                installGuidance: "Install Xcode or the Xcode Command Line Tools (xcode-select --install) on macOS, or install clang or gcc on Linux, and try again.")
        }
        return .available(toolPath: found, version: BackendToolDiscovery.toolVersion(found, arguments: ["--version"]))
    }

    public static func locateNim() -> String? {
        BackendToolDiscovery.locate(
            xcrunTool: nil,
            fixedPaths: ["/opt/homebrew/bin/nim", "/usr/local/bin/nim", "~/.nimble/bin/nim"],
            pathNames: ["nim"])
    }

    public static func rootFile(sources: [URL], projectRoot: URL, configuration: BuildConfiguration) -> URL {
        let module = SwiftBackend.moduleName(configuration: configuration)
        let candidates = ["Sources/lib.nim", "Sources/\(module).nim", "Sources/main.nim"]
        for candidate in candidates {
            let url = projectRoot.appendingPathComponent(candidate)
            if sources.contains(where: { $0.path == url.path }) { return url }
        }
        return sources.sorted { $0.path < $1.path }.first!
    }

    public func libraryArguments(sources: [URL], output: URL, projectRoot: URL, configuration: BuildConfiguration) -> [String] {
        let root = Self.rootFile(sources: sources, projectRoot: projectRoot, configuration: configuration)
        var args: [String] = []
        args.append("c")
        args.append("--app:lib")
        args.append("--noMain")
        args.append("--gc:orc")
        if configuration.optimizationLevel != "0" {
            args.append("-d:release")
        }
        args.append("--out:\(output.path)")
        args.append(root.path)
        args.append(contentsOf: configuration.perBackendFlags["nim"] ?? [])
        return args
    }

    public func parseDiagnostics(_ text: String, projectRoot: URL) -> [AssemblyDiagnostic] {
        var diagnostics = LibraryBackendSupport.parseParenthesizedDiagnostics(text, projectRoot: projectRoot)
        if !LibraryBackendSupport.anySourceContains(projectRoot: projectRoot, extensions: ["nim"], marker: "exportc") {
            diagnostics.append(AssemblyDiagnostic(
                severity: .warning,
                message: "No {.exportc.} procedure was found in the Nim sources. Only procedures marked {.exportc, dynlib, cdecl.} are visible to dlopen/dlsym.",
                origin: .projectConfiguration,
                suggestion: "Mark each exported procedure, for example proc sc_add(a: cint, b: cint): cint {.exportc, dynlib, cdecl.} = a + b"))
        }
        diagnostics.append(AssemblyDiagnostic(
            severity: .info,
            message: "The host must call NimMain() before any other export (or call an exported init procedure that calls NimMain) to initialise the Nim runtime and garbage collector; calling other exports first is undefined behaviour. The GC mode is ORC unless overridden with the nim per-backend flags.",
            origin: .projectConfiguration))
        if let warning = LibraryBackendSupport.multiArchitectureWarning(projectRoot: projectRoot) {
            diagnostics.append(warning)
        }
        return diagnostics
    }
}
