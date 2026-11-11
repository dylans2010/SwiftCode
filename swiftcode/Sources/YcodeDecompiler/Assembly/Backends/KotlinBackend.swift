import Foundation

public struct KotlinBackend: AssembleBackend {
    public init() {}

    public var id: String { "kotlin" }
    public var displayName: String { "Kotlin/Native" }
    public var kind: BackendKind { .native }
    public var buildMode: BackendBuildMode { .library }
    public var sourceExtensions: Set<String> { ["kt"] }

    public func availability(configuration: BuildConfiguration) -> BackendAvailability {
        guard let found = Self.locateGradle() else {
            return .unavailable(
                reason: "No Gradle installation was found.",
                installGuidance: "Install Gradle 8.5 or newer from https://gradle.org/install/ (or brew install gradle) and make sure gradle is on PATH, then try again.")
        }
        if BackendToolDiscovery.locateOnPATH(["java"]) == nil {
            return .unavailable(
                reason: "Gradle was found, but no Java runtime was found for it to run on.",
                installGuidance: "Install a JDK (for example brew install openjdk) and make sure java is on PATH, then try again.")
        }
        if ClangBackend.locateCompiler() == nil {
            return .unavailable(
                reason: "Kotlin/Native links native code, which needs a C compiler.",
                installGuidance: "Install Xcode or the Xcode Command Line Tools (xcode-select --install) on macOS and try again.")
        }
        if Self.targetName(configuration: configuration) == nil {
            return .unavailable(
                reason: "Kotlin/Native Apple targets cover arm64 and x86_64 macOS only.",
                installGuidance: "Set the build configuration architectures to arm64 or x86_64.")
        }
        return .available(toolPath: found, version: BackendToolDiscovery.toolVersion(found, arguments: ["--version"]))
    }

    public static func locateGradle() -> String? {
        BackendToolDiscovery.locate(
            xcrunTool: nil,
            fixedPaths: ["/opt/homebrew/bin/gradle", "/usr/local/bin/gradle"],
            pathNames: ["gradle"])
    }

    public static func targetName(configuration: BuildConfiguration) -> String? {
        switch configuration.architectures.first ?? .arm64 {
        case .arm64: return "macosArm64"
        case .x86_64: return "macosX64"
        default: return nil
        }
    }

    public static func linkTaskName(configuration: BuildConfiguration) -> String? {
        guard let target = targetName(configuration: configuration) else { return nil }
        let capitalized = target.prefix(1).uppercased() + target.dropFirst()
        return "linkDebugShared\(capitalized)"
    }

    public static func projectDirectory(projectRoot: URL) -> URL {
        projectRoot.appendingPathComponent("Build/Kotlin", isDirectory: true)
    }

    public static func baseName(configuration: BuildConfiguration) -> String {
        SwiftBackend.moduleName(configuration: configuration)
    }

    public static func settingsGradleContents(configuration: BuildConfiguration) -> String {
        "rootProject.name = \"\(SwiftBackend.moduleName(configuration: configuration))\"\n"
    }

    public static func buildGradleContents(projectRoot: URL, configuration: BuildConfiguration) -> String {
        guard let target = targetName(configuration: configuration),
              let linkTask = linkTaskName(configuration: configuration) else { return "" }
        let base = baseName(configuration: configuration)
        let outputDir = configuration.outputURL(in: projectRoot).deletingLastPathComponent().path
        return """
        plugins {
            kotlin("multiplatform") version "2.0.21"
        }

        repositories {
            mavenCentral()
        }

        kotlin {
            \(target) {
                binaries {
                    sharedLib {
                        baseName = "\(base)"
                    }
                }
            }
            sourceSets {
                val \(target)Main by getting {
                    kotlin.srcDir("../../Sources")
                }
            }
        }

        tasks.register<Copy>("copyBuiltDylib") {
            dependsOn("\(linkTask)")
            from("build/bin/\(target)/debugShared/lib\(base).dylib")
            into("\(outputDir)")
        }
        """
    }

    public func prepareProject(projectRoot: URL, configuration: BuildConfiguration) throws {
        guard Self.targetName(configuration: configuration) != nil else {
            throw DecompilerError.invalidRequest("Kotlin/Native Apple targets cover arm64 and x86_64 macOS only; the build configuration requests \(configuration.architectures.map(\.displayName).joined(separator: ", ")).")
        }
        let fm = FileManager.default
        let dir = Self.projectDirectory(projectRoot: projectRoot)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try Self.settingsGradleContents(configuration: configuration).write(
            to: dir.appendingPathComponent("settings.gradle.kts"), atomically: true, encoding: .utf8)
        try Self.buildGradleContents(projectRoot: projectRoot, configuration: configuration).write(
            to: dir.appendingPathComponent("build.gradle.kts"), atomically: true, encoding: .utf8)
    }

    public func libraryArguments(sources: [URL], output: URL, projectRoot: URL, configuration: BuildConfiguration) -> [String] {
        guard let linkTask = Self.linkTaskName(configuration: configuration) else { return [] }
        var args = [linkTask, "copyBuiltDylib"]
        args.append(contentsOf: configuration.perBackendFlags["kotlin"] ?? [])
        return args
    }

    public func libraryWorkingDirectory(projectRoot: URL, configuration: BuildConfiguration) -> URL? {
        Self.projectDirectory(projectRoot: projectRoot)
    }

    public func parseDiagnostics(_ text: String, projectRoot: URL) -> [AssemblyDiagnostic] {
        var diagnostics: [AssemblyDiagnostic] = []
        for rawLine in text.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            if line.hasPrefix("e: ") || line.contains(" error:") || line.hasPrefix("error:") {
                diagnostics.append(AssemblyDiagnostic(severity: .error, message: line,
                                                      origin: .userCode, rawText: rawLine))
                continue
            }
            if line.contains("FAILED") || line.hasPrefix("FAILURE:") {
                diagnostics.append(AssemblyDiagnostic(severity: .error, message: line,
                                                      origin: .projectConfiguration, rawText: rawLine))
            }
        }
        if let config = LibraryBackendSupport.storedConfiguration(projectRoot: projectRoot) {
            let base = Self.baseName(configuration: config)
            let target = Self.targetName(configuration: config) ?? "macosArm64"
            diagnostics.append(AssemblyDiagnostic(
                severity: .info,
                message: "Kotlin/Native does not export flat C symbols. Call the lib\(base)_symbols() gateway instead: dlsym the gateway function, which returns a lib\(base)_ExportedSymbols struct of function pointers for the Kotlin functions. The generated C header is Build/Kotlin/build/bin/\(target)/debugShared/lib\(base)_api.h.",
                origin: .projectConfiguration))
        }
        diagnostics.append(AssemblyDiagnostic(
            severity: .info,
            message: "Kotlin/Native Apple targets build on macOS only; the Kotlin Multiplatform plugin downloads from the Gradle Plugin Portal on first build, so that build needs network access.",
            origin: .projectConfiguration))
        if let warning = LibraryBackendSupport.multiArchitectureWarning(projectRoot: projectRoot) {
            diagnostics.append(warning)
        }
        return diagnostics
    }
}
