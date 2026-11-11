import Foundation

public struct ZigBackend: AssembleBackend {
    public init() {}

    public var id: String { "zig" }
    public var displayName: String { "Zig" }
    public var kind: BackendKind { .native }
    public var buildMode: BackendBuildMode { .library }
    public var sourceExtensions: Set<String> { ["zig"] }

    public func availability(configuration: BuildConfiguration) -> BackendAvailability {
        guard let found = Self.locateZig() else {
            return .unavailable(
                reason: "No Zig compiler was found.",
                installGuidance: "Install Zig from https://ziglang.org/download/ (or brew install zig) and make sure zig is on PATH, then try again.")
        }
        let version = BackendToolDiscovery.toolVersion(found, arguments: ["version"])
        if let version, let parsed = Self.parseVersion(version), parsed < (0, 11) {
            return .unavailable(
                reason: "Zig \(version) is too old; this backend needs Zig 0.11 or newer.",
                installGuidance: "Install Zig 0.11 or newer from https://ziglang.org/download/.")
        }
        return .available(toolPath: found, version: version)
    }

    public static func locateZig() -> String? {
        BackendToolDiscovery.locate(
            xcrunTool: nil,
            fixedPaths: ["/usr/local/bin/zig", "/opt/homebrew/bin/zig", "~/.local/bin/zig"],
            pathNames: ["zig"])
    }

    public static func parseVersion(_ text: String) -> (Int, Int)? {
        let parts = text.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ".")
        guard parts.count >= 2, let major = Int(parts[0]), let minor = Int(parts[1]) else { return nil }
        return (major, minor)
    }

    public static func rootFile(sources: [URL], projectRoot: URL, configuration: BuildConfiguration) -> URL {
        let module = SwiftBackend.moduleName(configuration: configuration)
        let candidates = ["Sources/root.zig", "Sources/\(module).zig", "Sources/main.zig"]
        for candidate in candidates {
            let url = projectRoot.appendingPathComponent(candidate)
            if sources.contains(where: { $0.path == url.path }) { return url }
        }
        return sources.sorted { $0.path < $1.path }.first!
    }

    public func libraryArguments(sources: [URL], output: URL, projectRoot: URL, configuration: BuildConfiguration) -> [String] {
        let root = Self.rootFile(sources: sources, projectRoot: projectRoot, configuration: configuration)
        var args = ["build-lib", root.path, "-dynamic", "-O", Self.optimizationMode(configuration.optimizationLevel),
                    "-femit-bin=\(output.path)"]
        args.append(contentsOf: configuration.perBackendFlags["zig"] ?? [])
        return args
    }

    public func parseDiagnostics(_ text: String, projectRoot: URL) -> [AssemblyDiagnostic] {
        AssemblyDiagnosticParser.parseCompilerOutput(text, projectRoot: projectRoot)
    }

    private static func optimizationMode(_ level: String) -> String {
        switch level {
        case "0": return "Debug"
        case "s", "z": return "ReleaseSmall"
        case "3": return "ReleaseFast"
        default: return "ReleaseSafe"
        }
    }
}
