import Foundation

public struct DBackend: AssembleBackend {
    public init() {}

    public var id: String { "d" }
    public var displayName: String { "D (LDC)" }
    public var kind: BackendKind { .native }
    public var buildMode: BackendBuildMode { .library }
    public var sourceExtensions: Set<String> { ["d"] }

    public func availability(configuration: BuildConfiguration) -> BackendAvailability {
        if let found = Self.locateLdc2() {
            return .available(toolPath: found, version: BackendToolDiscovery.toolVersion(found, arguments: ["--version"]))
        }
        if let dmd = Self.locateDmd() {
            return Self.dmdRefusal(dmdPath: dmd)
        }
        return .unavailable(
            reason: "No LDC compiler was found.",
            installGuidance: "Install LDC from https://github.com/ldc-developers/ldc/releases (or brew install ldc) and make sure ldc2 is on PATH, then try again.")
    }

    public static func locateLdc2() -> String? {
        BackendToolDiscovery.locate(
            xcrunTool: nil,
            fixedPaths: ["/opt/homebrew/bin/ldc2", "/usr/local/bin/ldc2", "~/.local/bin/ldc2"],
            pathNames: ["ldc2"])
    }

    public static func locateDmd() -> String? {
        BackendToolDiscovery.locate(
            xcrunTool: nil,
            fixedPaths: ["/opt/homebrew/bin/dmd", "/usr/local/bin/dmd"],
            pathNames: ["dmd"])
    }

    public static func dmdRefusal(dmdPath: String) -> BackendAvailability {
        .unavailable(
            reason: "DMD was found at \(dmdPath), but DMD cannot build shared libraries on macOS: it ships no shared druntime/Phobos (libphobos2.dylib) for Mach-O, so a DMD-built .dylib would have no working runtime.",
            installGuidance: "Install LDC instead (brew install ldc) — LDC supports shared druntime/Phobos on macOS — and make sure ldc2 is on PATH, then try again.")
    }

    public func libraryArguments(sources: [URL], output: URL, projectRoot: URL, configuration: BuildConfiguration) -> [String] {
        var args: [String] = []
        args.append("-shared")
        args.append("-of=\(output.path)")
        args.append(Self.optimizationFlag(configuration.optimizationLevel))
        args.append(contentsOf: sources.sorted { $0.path < $1.path }.map(\.path))
        args.append(contentsOf: configuration.perBackendFlags["d"] ?? [])
        return args
    }

    public func parseDiagnostics(_ text: String, projectRoot: URL) -> [AssemblyDiagnostic] {
        var diagnostics = LibraryBackendSupport.parseParenthesizedDiagnostics(text, projectRoot: projectRoot)
        if !LibraryBackendSupport.anySourceContains(projectRoot: projectRoot, extensions: ["d"], marker: "export") {
            diagnostics.append(AssemblyDiagnostic(
                severity: .warning,
                message: "No export attribute was found in the D sources. Only functions marked export (usually export extern(C)) are visible to dlopen/dlsym.",
                origin: .projectConfiguration,
                suggestion: "Mark each exported function, for example export extern(C) int sc_add(int a, int b) { return a + b; }"))
        }
        diagnostics.append(AssemblyDiagnostic(
            severity: .info,
            message: "This library links the shared LDC runtime (libphobos2-ldc-shared and libdruntime-ldc-shared) through @rpath; the host must have the LDC runtime libraries reachable at load time.",
            origin: .projectConfiguration))
        if let warning = LibraryBackendSupport.multiArchitectureWarning(projectRoot: projectRoot) {
            diagnostics.append(warning)
        }
        return diagnostics
    }

    private static func optimizationFlag(_ level: String) -> String {
        switch level {
        case "0": return "-O0"
        case "1": return "-O1"
        case "3": return "-O3"
        case "s", "z": return "-Os"
        default: return "-O2"
        }
    }
}
