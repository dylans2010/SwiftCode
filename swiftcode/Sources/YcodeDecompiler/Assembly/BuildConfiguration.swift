import Foundation
import YcodeSubprocess

public struct BuildConfiguration: Sendable, Codable {
    public var outputFileName: String
    public var outputDirectory: String?
    public var architectures: [BinaryArchitecture]
    public var deploymentTarget: String?
    public var sdk: String?
    public var compilerPath: String?
    public var optimizationLevel: String
    public var debugSymbols: Bool
    public var symbolVisibility: String
    public var exportedSymbols: [String]
    public var frameworks: [String]
    public var linkedLibraries: [String]
    public var headerSearchPaths: [String]
    public var librarySearchPaths: [String]
    public var definitions: [String]
    public var compilerFlags: [String]
    public var linkerFlags: [String]
    public var codeSignIdentity: String?
    public var runpaths: [String]
    public var installName: String?
    public var currentVersion: String?
    public var compatibilityVersion: String?
    public var universalBinary: Bool
    public var inferredSettings: [String]
    public var manualSettings: [String]
    public var unrecoveredSettings: [String]
    public var format: BinaryFormat = .unknown
    /// Target platform for Apple builds: "macos", "ios", "ios-simulator",
    /// "tvos", "tvos-simulator", "watchos", "watchos-simulator",
    /// "bridgeos", "mac-catalyst", "driverkit", "xros", "xros-simulator".
    /// nil means host platform / non-Apple format.
    public var platform: String? = nil
    /// SDK name or absolute path (e.g. "iphoneos", "macosx",
    /// "/Applications/Xcode.app/.../iPhoneOS.sdk"). Names are resolved via
    /// `xcrun --sdk <name> --show-sdk-path` at argument-build time.
    public var sdkName: String? = nil
    public var selectedBackendID: String? = nil
    public var perBackendFlags: [String: [String]] = [:]

    private enum CodingKeys: String, CodingKey {
        case outputFileName
        case outputDirectory
        case architectures
        case deploymentTarget
        case sdk
        case compilerPath
        case optimizationLevel
        case debugSymbols
        case symbolVisibility
        case exportedSymbols
        case frameworks
        case linkedLibraries
        case headerSearchPaths
        case librarySearchPaths
        case definitions
        case compilerFlags
        case linkerFlags
        case codeSignIdentity
        case runpaths
        case installName
        case currentVersion
        case compatibilityVersion
        case universalBinary
        case inferredSettings
        case manualSettings
        case unrecoveredSettings
        case format
        case platform
        case sdkName
        case selectedBackendID
        case perBackendFlags
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        outputFileName = try container.decodeIfPresent(String.self, forKey: .outputFileName) ?? "libreconstructed.dylib"
        outputDirectory = try container.decodeIfPresent(String.self, forKey: .outputDirectory)
        architectures = try container.decodeIfPresent([BinaryArchitecture].self, forKey: .architectures) ?? [.arm64]
        deploymentTarget = try container.decodeIfPresent(String.self, forKey: .deploymentTarget)
        sdk = try container.decodeIfPresent(String.self, forKey: .sdk)
        compilerPath = try container.decodeIfPresent(String.self, forKey: .compilerPath)
        optimizationLevel = try container.decodeIfPresent(String.self, forKey: .optimizationLevel) ?? "2"
        debugSymbols = try container.decodeIfPresent(Bool.self, forKey: .debugSymbols) ?? true
        symbolVisibility = try container.decodeIfPresent(String.self, forKey: .symbolVisibility) ?? "default"
        exportedSymbols = try container.decodeIfPresent([String].self, forKey: .exportedSymbols) ?? []
        frameworks = try container.decodeIfPresent([String].self, forKey: .frameworks) ?? []
        linkedLibraries = try container.decodeIfPresent([String].self, forKey: .linkedLibraries) ?? []
        headerSearchPaths = try container.decodeIfPresent([String].self, forKey: .headerSearchPaths) ?? []
        librarySearchPaths = try container.decodeIfPresent([String].self, forKey: .librarySearchPaths) ?? []
        definitions = try container.decodeIfPresent([String].self, forKey: .definitions) ?? []
        compilerFlags = try container.decodeIfPresent([String].self, forKey: .compilerFlags) ?? []
        linkerFlags = try container.decodeIfPresent([String].self, forKey: .linkerFlags) ?? []
        codeSignIdentity = try container.decodeIfPresent(String.self, forKey: .codeSignIdentity)
        runpaths = try container.decodeIfPresent([String].self, forKey: .runpaths) ?? []
        installName = try container.decodeIfPresent(String.self, forKey: .installName)
        currentVersion = try container.decodeIfPresent(String.self, forKey: .currentVersion)
        compatibilityVersion = try container.decodeIfPresent(String.self, forKey: .compatibilityVersion)
        universalBinary = try container.decodeIfPresent(Bool.self, forKey: .universalBinary) ?? false
        inferredSettings = try container.decodeIfPresent([String].self, forKey: .inferredSettings) ?? []
        manualSettings = try container.decodeIfPresent([String].self, forKey: .manualSettings) ?? []
        unrecoveredSettings = try container.decodeIfPresent([String].self, forKey: .unrecoveredSettings) ?? []
        format = try container.decodeIfPresent(BinaryFormat.self, forKey: .format) ?? .unknown
        platform = try container.decodeIfPresent(String.self, forKey: .platform)
        sdkName = try container.decodeIfPresent(String.self, forKey: .sdkName)
        selectedBackendID = try container.decodeIfPresent(String.self, forKey: .selectedBackendID)
        perBackendFlags = try container.decodeIfPresent([String: [String]].self, forKey: .perBackendFlags) ?? [:]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(outputFileName, forKey: .outputFileName)
        try container.encode(outputDirectory, forKey: .outputDirectory)
        try container.encode(architectures, forKey: .architectures)
        try container.encode(deploymentTarget, forKey: .deploymentTarget)
        try container.encode(sdk, forKey: .sdk)
        try container.encode(compilerPath, forKey: .compilerPath)
        try container.encode(optimizationLevel, forKey: .optimizationLevel)
        try container.encode(debugSymbols, forKey: .debugSymbols)
        try container.encode(symbolVisibility, forKey: .symbolVisibility)
        try container.encode(exportedSymbols, forKey: .exportedSymbols)
        try container.encode(frameworks, forKey: .frameworks)
        try container.encode(linkedLibraries, forKey: .linkedLibraries)
        try container.encode(headerSearchPaths, forKey: .headerSearchPaths)
        try container.encode(librarySearchPaths, forKey: .librarySearchPaths)
        try container.encode(definitions, forKey: .definitions)
        try container.encode(compilerFlags, forKey: .compilerFlags)
        try container.encode(linkerFlags, forKey: .linkerFlags)
        try container.encode(codeSignIdentity, forKey: .codeSignIdentity)
        try container.encode(runpaths, forKey: .runpaths)
        try container.encode(installName, forKey: .installName)
        try container.encode(currentVersion, forKey: .currentVersion)
        try container.encode(compatibilityVersion, forKey: .compatibilityVersion)
        try container.encode(universalBinary, forKey: .universalBinary)
        try container.encode(inferredSettings, forKey: .inferredSettings)
        try container.encode(manualSettings, forKey: .manualSettings)
        try container.encode(unrecoveredSettings, forKey: .unrecoveredSettings)
        try container.encode(format, forKey: .format)
        try container.encode(platform, forKey: .platform)
        try container.encode(sdkName, forKey: .sdkName)
        try container.encode(selectedBackendID, forKey: .selectedBackendID)
        try container.encode(perBackendFlags, forKey: .perBackendFlags)
    }

    public init(outputFileName: String, outputDirectory: String? = nil,
                architectures: [BinaryArchitecture] = [.arm64],
                deploymentTarget: String? = nil, sdk: String? = nil,
                compilerPath: String? = nil, optimizationLevel: String = "2",
                debugSymbols: Bool = true, symbolVisibility: String = "default",
                exportedSymbols: [String] = [], frameworks: [String] = [],
                linkedLibraries: [String] = [], headerSearchPaths: [String] = [],
                librarySearchPaths: [String] = [], definitions: [String] = [],
                compilerFlags: [String] = [], linkerFlags: [String] = [],
                codeSignIdentity: String? = nil, runpaths: [String] = [],
                installName: String? = nil, currentVersion: String? = nil,
                compatibilityVersion: String? = nil, universalBinary: Bool = false,
                inferredSettings: [String] = [], manualSettings: [String] = [],
                unrecoveredSettings: [String] = [], format: BinaryFormat = .unknown,
                platform: String? = nil, sdkName: String? = nil,
                selectedBackendID: String? = nil, perBackendFlags: [String: [String]] = [:]) {
        self.outputFileName = outputFileName
        self.outputDirectory = outputDirectory
        self.architectures = architectures
        self.deploymentTarget = deploymentTarget
        self.sdk = sdk
        self.compilerPath = compilerPath
        self.optimizationLevel = optimizationLevel
        self.debugSymbols = debugSymbols
        self.symbolVisibility = symbolVisibility
        self.exportedSymbols = exportedSymbols
        self.frameworks = frameworks
        self.linkedLibraries = linkedLibraries
        self.headerSearchPaths = headerSearchPaths
        self.librarySearchPaths = librarySearchPaths
        self.definitions = definitions
        self.compilerFlags = compilerFlags
        self.linkerFlags = linkerFlags
        self.codeSignIdentity = codeSignIdentity
        self.runpaths = runpaths
        self.installName = installName
        self.currentVersion = currentVersion
        self.compatibilityVersion = compatibilityVersion
        self.universalBinary = universalBinary
        self.inferredSettings = inferredSettings
        self.manualSettings = manualSettings
        self.unrecoveredSettings = unrecoveredSettings
        self.format = format
        self.platform = platform
        self.sdkName = sdkName
        self.selectedBackendID = selectedBackendID
        self.perBackendFlags = perBackendFlags
    }

    public static func inferred(from image: BinaryImage, libraryName: String) -> BuildConfiguration {
        let outputFileName: String
        switch image.format {
        case .machO: outputFileName = "lib\(libraryName).dylib"
        case .elf: outputFileName = "lib\(libraryName).so"
        case .pe: outputFileName = "\(libraryName).dll"
        case .unknown: outputFileName = "lib\(libraryName).dylib"
        }
        var inferred: [String] = ["outputFileName", "architectures"]
        var unrecovered: [String] = []
        let deploymentTarget = image.minOSVersion
        if deploymentTarget != nil { inferred.append("deploymentTarget") }
        else { unrecovered.append("deploymentTarget") }
        var installName = image.installName
        if installName != nil { inferred.append("installName") }
        else {
            installName = "@rpath/\(outputFileName)"
            unrecovered.append("installName (defaulted to @rpath/\(outputFileName))")
        }
        var runpaths = image.runpaths
        if !runpaths.isEmpty { inferred.append("runpaths") }
        else {
            runpaths = ["@loader_path"]
            unrecovered.append("runpaths (defaulted to @loader_path)")
        }
        var frameworks: [String] = []
        var linkedLibraries: [String] = []
        for dep in image.dependencies {
            let base = (dep.path as NSString).lastPathComponent
            if base.hasSuffix(".framework") {
                frameworks.append(String(base.dropLast(".framework".count)))
            } else if base.hasPrefix("lib") && (base.hasSuffix(".dylib") || base.hasSuffix(".tbd")) {
                var lib = String(base.dropFirst(3))
                if lib.hasSuffix(".dylib") { lib = String(lib.dropLast(6)) }
                if lib.hasSuffix(".tbd") { lib = String(lib.dropLast(4)) }
                // Versioned install names (libSystem.B.dylib, libc++.1.dylib)
                // map to the unversioned -l name the SDK provides.
                if let dot = lib.firstIndex(of: ".") { lib = String(lib[..<dot]) }
                if !lib.isEmpty { linkedLibraries.append(lib) }
            }
        }
        linkedLibraries = Array(Set(linkedLibraries)).sorted()
        frameworks = Array(Set(frameworks)).sorted()
        let platform = image.targetPlatform
        let sdkName = platform.map { Self.defaultSDKName(for: $0) }
        if platform != nil { inferred.append("platform") }
        if sdkName != nil { inferred.append("sdk") }
        if !frameworks.isEmpty || !linkedLibraries.isEmpty { inferred.append("dependencies") }
        var config = BuildConfiguration(
            outputFileName: outputFileName,
            architectures: [image.architecture],
            deploymentTarget: deploymentTarget,
            optimizationLevel: "2",
            debugSymbols: image.hasDebugInfo,
            exportedSymbols: image.exports.map(\.name),
            frameworks: frameworks,
            linkedLibraries: linkedLibraries,
            runpaths: runpaths,
            installName: installName,
            universalBinary: false,
            format: image.format,
            platform: platform,
            sdkName: sdkName)
        var backendsToCheck: [any AssembleBackend] = [ClangBackend()]
        switch LanguageIdentification.identify(image: image) {
        case .swift: backendsToCheck.append(SwiftBackend())
        case .rust: backendsToCheck.append(RustBackend())
        case .go: backendsToCheck.append(GoBackend())
        default: break
        }
        for backend in backendsToCheck {
            if case .unavailable(let reason, _) = backend.availability(configuration: config) {
                unrecovered.append("toolchain: \(backend.displayName) unavailable (\(reason))")
            }
        }
        config.inferredSettings = inferred
        config.unrecoveredSettings = unrecovered
        return config
    }

    public func outputURL(in projectRoot: URL) -> URL {
        if let dir = outputDirectory {
            return URL(fileURLWithPath: dir).appendingPathComponent(outputFileName)
        }
        return projectRoot.appendingPathComponent("Build").appendingPathComponent(outputFileName)
    }

    public func compileArguments(source: URL, object: URL, projectRoot: URL,
                                 format: BinaryFormat) -> [String] {
        var args: [String] = []
        args.append("-c")
        args.append(source.path)
        args.append("-o")
        args.append(object.path)
        args.append("-O\(optimizationLevel)")
        if debugSymbols { args.append("-g") }
        args.append("-fvisibility=\(symbolVisibility)")
        if format == .machO {
            for arch in architectures {
                args.append("-arch")
                args.append(arch.clangName)
            }
            if let sdkPath = resolvedSDKPath() {
                args.append("-isysroot")
                args.append(sdkPath)
            }
            if let deploymentTarget, let minFlag = Self.deploymentMinFlag(for: platform) {
                args.append("\(minFlag)=\(deploymentTarget)")
            }
        } else {
            args.append("-fPIC")
        }
        for path in headerSearchPaths {
            args.append("-I")
            args.append(path)
        }
        args.append("-I")
        args.append(projectRoot.appendingPathComponent("Headers").path)
        for define in definitions {
            args.append("-D")
            args.append(define)
        }
        args.append(contentsOf: compilerFlags)
        return args
    }

    public func linkArguments(objects: [URL], output: URL, format: BinaryFormat) -> [String] {
        var args: [String] = []
        if format == .machO {
            args.append("-dynamiclib")
        } else {
            args.append("-shared")
        }
        args.append(contentsOf: objects.map(\.path))
        args.append("-o")
        args.append(output.path)
        if format == .machO {
            for arch in architectures {
                args.append("-arch")
                args.append(arch.clangName)
            }
            if let deploymentTarget, let minFlag = Self.deploymentMinFlag(for: platform) {
                args.append("\(minFlag)=\(deploymentTarget)")
            }
            if let sdkPath = resolvedSDKPath() {
                args.append("-isysroot")
                args.append(sdkPath)
            }
            if let installName {
                args.append("-install_name")
                args.append(installName)
            }
            for runpath in runpaths {
                args.append("-Wl,-rpath,\(runpath)")
            }
            for framework in frameworks {
                args.append("-framework")
                args.append(framework)
            }
        } else {
            for runpath in runpaths where runpath != "@loader_path" {
                args.append("-Wl,-rpath,\(runpath)")
            }
        }
        for path in librarySearchPaths {
            args.append("-L")
            args.append(path)
        }
        for library in linkedLibraries {
            args.append("-l\(library)")
        }
        args.append(contentsOf: linkerFlags)
        return args
    }

    // MARK: - Platform / SDK resolution

    /// Canonical SDK name for an Apple target platform (xcrun --sdk name).
    public static func defaultSDKName(for platform: String?) -> String {
        switch platform {
        case "ios", "ios-simulator", "mac-catalyst": return "iphoneos"
        case "tvos", "tvos-simulator": return "appletvos"
        case "watchos", "watchos-simulator": return "watchos"
        case "xros", "xros-simulator": return "xros"
        case "bridgeos": return "bridgeos"
        case "driverkit": return "driverkit"
        default: return "macosx"
        }
    }

    /// clang `-m…-version-min` flag stem for the platform, or nil when the
    /// platform is unknown/host (caller then emits no deployment flag).
    public static func deploymentMinFlag(for platform: String?) -> String? {
        switch platform {
        case "macos": return "-mmacosx-version-min"
        case "ios": return "-miphoneos-version-min"
        case "ios-simulator": return "-mios-simulator-version-min"
        case "tvos": return "-mtvos-version-min"
        case "tvos-simulator": return "-mtvos-simulator-version-min"
        case "watchos": return "-mwatchos-version-min"
        case "watchos-simulator": return "-mwatchos-simulator-version-min"
        case "bridgeos": return "-mbridgeos-version-min"
        case "xros": return "-mxros-version-min"
        case "xros-simulator": return "-mxros-simulator-version-min"
        case "mac-catalyst", "driverkit": return nil
        default: return "-mmacosx-version-min"
        }
    }

    /// Resolve `sdk`/`sdkName` to an SDK path. Absolute paths pass through;
    /// names go through `xcrun --sdk <name> --show-sdk-path` (cached).
    /// Returns nil when no SDK can be resolved — callers then omit
    /// `-isysroot` and the compiler default applies.
    public func resolvedSDKPath() -> String? {
        if let sdk, sdk.hasPrefix("/") { return sdk }
        let name = sdkName ?? sdk
        guard let name, !name.isEmpty else { return nil }
        if name.hasPrefix("/") { return name }
        return Self.sdkPathCache.path(for: name)
    }

    /// Process-wide cache of xcrun SDK resolutions.
    private static let sdkPathCache = SDKPathCache()

    private final class SDKPathCache: @unchecked Sendable {
        private let lock = NSLock()
        private var paths: [String: String?] = [:]

        func path(for name: String) -> String? {
            lock.lock()
            if let cached = paths[name] { lock.unlock(); return cached }
            lock.unlock()

            var resolved: String?
            for xcrun in ["/usr/bin/xcrun", "/bin/xcrun"]
            where FileManager.default.isExecutableFile(atPath: xcrun) {
                if let out = try? Subprocess.run(
                    xcrun, ["--sdk", name, "--show-sdk-path"],
                    captureStderr: false),
                   out.status == 0 {
                    let path = out.stdoutText
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !path.isEmpty, path.hasPrefix("/") {
                        resolved = path
                        break
                    }
                }
            }
            // Fall back to well-known SDK directories when xcrun is absent
            // or the named SDK is not installed.
            if resolved == nil {
                let candidates = [
                    "/Library/Developer/CommandLineTools/SDKs/\(sdkFileName(for: name))",
                    "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/\(sdkFileName(for: name))",
                ]
                for candidate in candidates where FileManager.default.fileExists(atPath: candidate) {
                    resolved = candidate
                    break
                }
            }

            lock.lock()
            paths[name] = resolved
            lock.unlock()
            return resolved
        }

        private func sdkFileName(for name: String) -> String {
            switch name {
            case "macosx": return "MacOSX.sdk"
            case "iphoneos": return "iPhoneOS.sdk"
            case "appletvos": return "AppleTVOS.sdk"
            case "watchos": return "WatchOS.sdk"
            case "xros": return "XRSimulator.sdk"
            case "bridgeos": return "iPhoneOS.sdk"
            case "driverkit": return "DriverKit.sdk"
            default: return "\(name).sdk"
            }
        }
    }
}

extension BinaryArchitecture {
    public var clangName: String {
        switch self {
        case .arm64: return "arm64"
        case .arm64_32: return "arm64_32"
        case .x86_64: return "x86_64"
        case .armv7: return "armv7"
        case .armv7s: return "armv7s"
        case .armv6: return "armv6"
        case .i386: return "i386"
        case .riscv64: return "riscv64"
        case .powerpc: return "ppc"
        case .powerpc64: return "ppc64"
        case .mips: return "mips"
        case .unknown: return "arm64"
        }
    }
}
