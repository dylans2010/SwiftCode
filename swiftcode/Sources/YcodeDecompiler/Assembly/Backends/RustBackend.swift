import Foundation

public struct RustBackend: AssembleBackend {
    public init() {}

    public var id: String { "rust" }
    public var displayName: String { "Rust" }
    public var kind: BackendKind { .native }
    public var buildMode: BackendBuildMode { .library }
    public var sourceExtensions: Set<String> { ["rs"] }

    public func availability(configuration: BuildConfiguration) -> BackendAvailability {
        if let found = Self.locateRustc() {
            return .available(toolPath: found, version: BackendToolDiscovery.toolVersion(found))
        }
        return .unavailable(
            reason: "No Rust compiler was found.",
            installGuidance: "Install Rust via rustup (https://rustup.rs) and make sure rustc is on PATH, then try again.")
    }

    public static func locateRustc() -> String? {
        BackendToolDiscovery.locate(
            xcrunTool: nil,
            fixedPaths: ["/usr/local/bin/rustc", "/opt/homebrew/bin/rustc", "~/.cargo/bin/rustc"],
            pathNames: ["rustc"])
    }

    public static func crateRoot(sources: [URL], projectRoot: URL, configuration: BuildConfiguration) -> URL {
        let module = SwiftBackend.moduleName(configuration: configuration)
        let candidates = ["Sources/lib.rs", "Sources/\(module).rs", "Sources/main.rs"]
        for candidate in candidates {
            let url = projectRoot.appendingPathComponent(candidate)
            if sources.contains(where: { $0.path == url.path }) { return url }
        }
        return sources.sorted { $0.path < $1.path }.first!
    }

    public func libraryArguments(sources: [URL], output: URL, projectRoot: URL, configuration: BuildConfiguration) -> [String] {
        let root = Self.crateRoot(sources: sources, projectRoot: projectRoot, configuration: configuration)
        var args: [String] = []
        args.append("--crate-type")
        args.append("cdylib")
        args.append("--edition")
        args.append("2021")
        args.append("-C")
        args.append("opt-level=\(Self.optimizationLevel(configuration.optimizationLevel))")
        args.append("-C")
        args.append("debuginfo=\(configuration.debugSymbols ? "2" : "0")")
        if configuration.format == .machO {
            if let installName = configuration.installName {
                args.append("-C")
                args.append("link-arg=-Wl,-install_name,\(installName)")
            }
            for runpath in configuration.runpaths {
                args.append("-C")
                args.append("link-arg=-Wl,-rpath,\(runpath)")
            }
        }
        args.append("-o")
        args.append(output.path)
        args.append(root.path)
        args.append(contentsOf: configuration.perBackendFlags["rust"] ?? [])
        return args
    }

    public func parseDiagnostics(_ text: String, projectRoot: URL) -> [AssemblyDiagnostic] {
        var diagnostics: [AssemblyDiagnostic] = []
        var pending: AssemblyDiagnostic?
        for rawLine in text.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line.hasPrefix("--> ") {
                let location = String(line.dropFirst(4))
                let parts = location.split(separator: ":")
                if parts.count >= 3,
                   let lineNumber = Int(parts[parts.count - 2]),
                   let columnNumber = Int(parts[parts.count - 1]) {
                    var file = parts.dropLast(2).joined(separator: ":")
                    if file.hasPrefix(projectRoot.path) {
                        file = String(file.dropFirst(projectRoot.path.count + 1))
                    }
                    pending?.file = file
                    pending?.line = lineNumber
                    pending?.column = columnNumber
                }
                continue
            }
            if line.hasPrefix("error") || line.hasPrefix("warning") {
                if let diag = pending { diagnostics.append(diag) }
                let severity: AssemblyDiagnostic.Severity = line.hasPrefix("error") ? .error : .warning
                pending = AssemblyDiagnostic(severity: severity, message: line, origin: .userCode, rawText: rawLine)
                continue
            }
            if line.hasPrefix("note:") || line.hasPrefix("help:") {
                if pending != nil { pending?.message += " " + line }
                continue
            }
        }
        if let diag = pending { diagnostics.append(diag) }
        return diagnostics
    }

    private static func optimizationLevel(_ level: String) -> String {
        switch level {
        case "0": return "0"
        case "1": return "1"
        case "3": return "3"
        case "s", "z": return "s"
        default: return "2"
        }
    }
}
