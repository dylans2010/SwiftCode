import Foundation

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
        var deploymentTarget = image.minOSVersion
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
                linkedLibraries.append(lib)
            }
        }
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
            format: image.format)
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
            if let sdk {
                args.append("-isysroot")
                args.append(sdk)
            }
            if let deploymentTarget {
                args.append("-mmacosx-version-min=\(deploymentTarget)")
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
            if let deploymentTarget {
                args.append("-mmacosx-version-min=\(deploymentTarget)")
            }
            if let sdk {
                args.append("-isysroot")
                args.append(sdk)
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
