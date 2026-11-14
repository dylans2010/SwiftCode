import Foundation

public struct ReconstructedProject: Sendable {
    public var rootURL: URL
    public var libraryName: String
    public var source: ReconstructedSource
    public var configuration: BuildConfiguration
    public var manifest: ReconstructedProjectManifest
    public var createdAt: Date

    public init(rootURL: URL, libraryName: String, source: ReconstructedSource,
                configuration: BuildConfiguration, manifest: ReconstructedProjectManifest,
                createdAt: Date = Date()) {
        self.rootURL = rootURL
        self.libraryName = libraryName
        self.source = source
        self.configuration = configuration
        self.manifest = manifest
        self.createdAt = createdAt
    }

    public var packageManifestURL: URL { rootURL.appendingPathComponent("Package.swift") }
    public var sourceMapURL: URL { rootURL.appendingPathComponent("Mappings/source-map.json") }
    public var buildConfigurationURL: URL { rootURL.appendingPathComponent("Build/build-config.json") }
}

public struct ReconstructedProjectManifest: Sendable, Codable {
    public var schemaVersion: Int
    public var libraryName: String
    public var originalFileName: String
    public var originalSHA256: String
    public var originalFormat: String
    public var originalArchitecture: String
    public var originalInstallName: String?
    public var originalUUID: String?
    public var originalDependencies: [String]
    public var originalExports: [String]
    public var generatedAt: Date
    public var generatorVersion: String
    public var language: String
    public var fileLanguages: [String: String]
    public var qualityCounts: [String: Int]
    public var enginesUsed: [String]
    public var decompilerAvailable: Bool
    public var files: [String]

    public init(schemaVersion: Int = 1, libraryName: String, originalFileName: String,
                originalSHA256: String, originalFormat: String, originalArchitecture: String,
                originalInstallName: String? = nil, originalUUID: String? = nil,
                originalDependencies: [String] = [], originalExports: [String] = [],
                generatedAt: Date = Date(), generatorVersion: String = "1.0.0",
                language: String, fileLanguages: [String: String] = [:],
                qualityCounts: [String: Int] = [:],
                enginesUsed: [String] = [], decompilerAvailable: Bool, files: [String] = []) {
        self.schemaVersion = schemaVersion
        self.libraryName = libraryName
        self.originalFileName = originalFileName
        self.originalSHA256 = originalSHA256
        self.originalFormat = originalFormat
        self.originalArchitecture = originalArchitecture
        self.originalInstallName = originalInstallName
        self.originalUUID = originalUUID
        self.originalDependencies = originalDependencies
        self.originalExports = originalExports
        self.generatedAt = generatedAt
        self.generatorVersion = generatorVersion
        self.language = language
        self.fileLanguages = fileLanguages
        self.qualityCounts = qualityCounts
        self.enginesUsed = enginesUsed
        self.decompilerAvailable = decompilerAvailable
        self.files = files
    }
}

public enum ReconstructedProjectGenerator {
    public static func generate(source: ReconstructedSource, image: BinaryImage,
                                configuration: BuildConfiguration,
                                at rootURL: URL) throws -> ReconstructedProject {
        let fm = FileManager.default
        let directories = ["Sources", "Headers", "Types", "Generated", "Assembly", "Metadata",
                           "Dependencies", "Build", "Diagnostics", "Mappings", "Reports",
                           "ProjectConfiguration"]
        for dir in directories {
            try fm.createDirectory(at: rootURL.appendingPathComponent(dir, isDirectory: true),
                                   withIntermediateDirectories: true)
        }
        var writtenFiles: [String] = []
        for file in source.files {
            let url = rootURL.appendingPathComponent(file.relativePath)
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try file.contents.write(to: url, atomically: true, encoding: .utf8)
            writtenFiles.append(file.relativePath)
        }
        let packageText = packageManifest(libraryName: source.libraryName, configuration: configuration,
                                          sourceFiles: source.files)
        try packageText.write(to: rootURL.appendingPathComponent("Package.swift"),
                              atomically: true, encoding: .utf8)
        writtenFiles.append("Package.swift")
        let cmakeText = cmakeLists(libraryName: source.libraryName, configuration: configuration,
                                   sourceFiles: source.files)
        try cmakeText.write(to: rootURL.appendingPathComponent("Build/CMakeLists.txt"),
                            atomically: true, encoding: .utf8)
        writtenFiles.append("Build/CMakeLists.txt")
        let configData = try JSONEncoder().encode(configuration)
        try configData.write(to: rootURL.appendingPathComponent("Build/build-config.json"))
        writtenFiles.append("Build/build-config.json")
        let mapData = try source.sourceMap.jsonData()
        try mapData.write(to: rootURL.appendingPathComponent("Mappings/source-map.json"))
        writtenFiles.append("Mappings/source-map.json")
        let report = reconstructionReport(source: source, image: image, configuration: configuration)
        try report.write(to: rootURL.appendingPathComponent("Diagnostics/reconstruction-report.md"),
                         atomically: true, encoding: .utf8)
        writtenFiles.append("Diagnostics/reconstruction-report.md")
        let readme = projectReadme(source: source, image: image, configuration: configuration)
        try readme.write(to: rootURL.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        writtenFiles.append("README.md")
        let metadata = originalMetadata(image: image)
        let metadataData = try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
        try metadataData.write(to: rootURL.appendingPathComponent("Metadata/original.json"))
        writtenFiles.append("Metadata/original.json")

        var qualityCounts: [String: Int] = [:]
        for record in source.records {
            qualityCounts[record.quality.rawValue, default: 0] += 1
        }
        var fileLanguages: [String: String] = [:]
        for file in source.files {
            fileLanguages[file.relativePath] = file.language.rawValue
        }
        let manifest = ReconstructedProjectManifest(
            libraryName: source.libraryName,
            originalFileName: image.identity.originalFileName,
            originalSHA256: image.identity.sha256,
            originalFormat: image.format.rawValue,
            originalArchitecture: image.architecture.rawValue,
            originalInstallName: image.installName,
            originalUUID: image.identity.binaryUUID,
            originalDependencies: image.dependencies.map(\.path),
            originalExports: source.exportedNames,
            language: source.language.rawValue,
            fileLanguages: fileLanguages,
            qualityCounts: qualityCounts,
            enginesUsed: source.enginesUsed,
            decompilerAvailable: source.decompilerAvailable,
            files: writtenFiles.sorted())
        let manifestData = try JSONEncoder().encode(manifest)
        let manifestURL = rootURL.appendingPathComponent("ProjectConfiguration/manifest.json")
        try manifestData.write(to: manifestURL)
        return ReconstructedProject(rootURL: rootURL, libraryName: source.libraryName, source: source,
                                    configuration: configuration, manifest: manifest)
    }

    public static func packageManifest(libraryName: String, configuration: BuildConfiguration,
                                       sourceFiles: [GeneratedSourceFile]) -> String {
        let cFamilyExtensions: Set<String> = ["c", "m", "mm", "cpp", "cc", "cxx", "s", "S"]
        let projectFiles = sourceFiles.filter {
            $0.relativePath.hasPrefix("Sources/") || $0.relativePath.hasPrefix("Assembly/")
        }
        let cSources = projectFiles.filter { cFamilyExtensions.contains(($0.relativePath as NSString).pathExtension) }
        let swiftSources = projectFiles.filter { ($0.relativePath as NSString).pathExtension == "swift" }
        let otherSources = projectFiles.filter {
            !cFamilyExtensions.contains(($0.relativePath as NSString).pathExtension)
                && ($0.relativePath as NSString).pathExtension != "swift"
        }
        var targetNames: [String] = []
        var lines: [String] = []
        lines.append("// swift-tools-version: 5.9")
        lines.append("import PackageDescription")
        lines.append("")
        if !otherSources.isEmpty {
            lines.append("// Assembled by SwiftCode, not SwiftPM: \(otherSources.map(\.relativePath).joined(separator: ", "))")
            lines.append("")
        }
        lines.append("let package = Package(")
        lines.append("    name: \"\(libraryName)\",")
        lines.append("    products: [")
        if !cSources.isEmpty || !swiftSources.isEmpty {
            if !cSources.isEmpty { targetNames.append(libraryName) }
            if !swiftSources.isEmpty { targetNames.append("\(libraryName)Swift") }
            lines.append("        .library(name: \"\(libraryName)\", type: .dynamic, targets: [\(targetNames.map { "\"\($0)\"" }.joined(separator: ", "))]),")
        }
        lines.append("    ],")
        lines.append("    targets: [")
        if !cSources.isEmpty {
            lines.append("        .target(")
            lines.append("            name: \"\(libraryName)\",")
            
            
            lines.append("            path: \".\",")
            lines.append("            sources: [\(cSources.map { "\"\($0.relativePath)\"" }.joined(separator: ", "))],")
            lines.append("            publicHeadersPath: \"Headers\",")
            lines.append("            cSettings: [")
            for define in configuration.definitions {
                lines.append("                .define(\"\(define)\"),")
            }
            lines.append("                .unsafeFlags([\"-O\(configuration.optimizationLevel)\"])")
            lines.append("            ],")
            lines.append("            linkerSettings: [")
            for framework in configuration.frameworks {
                lines.append("                .linkedFramework(\"\(framework)\"),")
            }
            for library in configuration.linkedLibraries {
                lines.append("                .linkedLibrary(\"\(library)\"),")
            }
            lines.append("            ]")
            lines.append("        ),")
        }
        if !swiftSources.isEmpty {
            lines.append("        .target(")
            lines.append("            name: \"\(libraryName)Swift\",")
            lines.append("            path: \".\",")
            if !cSources.isEmpty {
                lines.append("            dependencies: [\"\(libraryName)\"],")
            }
            lines.append("            sources: [\(swiftSources.map { "\"\($0.relativePath)\"" }.joined(separator: ", "))]")
            lines.append("        ),")
        }
        lines.append("    ]")
        lines.append(")")
        return lines.joined(separator: "\n") + "\n"
    }

    public static func cmakeLists(libraryName: String, configuration: BuildConfiguration,
                                  sourceFiles: [GeneratedSourceFile]) -> String {
        let cFamilyExtensions: Set<String> = ["c", "m", "mm", "cpp", "cc", "cxx", "s", "S"]
        let projectFiles = sourceFiles.filter {
            $0.relativePath.hasPrefix("Sources/") || $0.relativePath.hasPrefix("Assembly/")
        }
        let extensions = Set(projectFiles.map { ($0.relativePath as NSString).pathExtension })
        var languages: [String] = []
        if !extensions.intersection(["c", "m", "s", "S"]).isEmpty { languages.append("C") }
        if !extensions.intersection(["cpp", "cc", "cxx", "mm"]).isEmpty { languages.append("CXX") }
        if extensions.contains("swift") { languages.append("Swift") }
        if !extensions.intersection(["s", "S"]).isEmpty { languages.append("ASM") }
        if languages.isEmpty { languages = ["C"] }
        let buildableFiles = projectFiles.filter {
            cFamilyExtensions.contains(($0.relativePath as NSString).pathExtension)
                || ($0.relativePath as NSString).pathExtension == "swift"
        }
        let otherFiles = projectFiles.filter {
            !cFamilyExtensions.contains(($0.relativePath as NSString).pathExtension)
                && ($0.relativePath as NSString).pathExtension != "swift"
        }
        var lines: [String] = []
        lines.append("cmake_minimum_required(VERSION 3.20)")
        lines.append("project(\(libraryName) \(languages.joined(separator: " ")))")
        lines.append("")
        if !otherFiles.isEmpty {
            lines.append("# Assembled by SwiftCode, not CMake: \(otherFiles.map(\.relativePath).joined(separator: ", "))")
            lines.append("")
        }
        lines.append("add_library(\(libraryName) SHARED")
        for file in buildableFiles {
            lines.append("    ${CMAKE_CURRENT_SOURCE_DIR}/../\(file.relativePath)")
        }
        lines.append(")")
        lines.append("")
        lines.append("target_include_directories(\(libraryName) PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/../Headers)")
        for dir in configuration.headerSearchPaths {
            lines.append("target_include_directories(\(libraryName) PRIVATE \(dir))")
        }
        for framework in configuration.frameworks {
            lines.append("target_link_libraries(\(libraryName) PRIVATE \"-framework \(framework)\")")
        }
        for library in configuration.linkedLibraries {
            lines.append("target_link_libraries(\(libraryName) PRIVATE \(library))")
        }
        if let installName = configuration.installName {
            lines.append("set_target_properties(\(libraryName) PROPERTIES INSTALL_NAME_DIR \"\(installName)\" BUILD_WITH_INSTALL_NAME_DIR TRUE)")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func reconstructionReport(source: ReconstructedSource, image: BinaryImage,
                                             configuration: BuildConfiguration) -> String {
        var lines: [String] = []
        lines.append("# Reconstruction Report — \(source.libraryName)")
        lines.append("")
        lines.append("Original: \(image.identity.originalFileName) (\(image.format.displayName), \(image.architecture.displayName), SHA-256 \(image.identity.sha256))")
        lines.append("Generated: \(Date())")
        lines.append("Language estimate: \(source.language.displayName)")
        lines.append("Decompiler backend available: \(source.decompilerAvailable ? "yes" : "no")")
        lines.append("Engines used: \(source.enginesUsed.isEmpty ? "none" : source.enginesUsed.joined(separator: ", "))")
        lines.append("")
        lines.append("## Quality counts")
        var counts: [String: Int] = [:]
        for record in source.records { counts[record.quality.rawValue, default: 0] += 1 }
        for quality in ReconstructionQuality.allCases {
            lines.append("- \(quality.displayName): \(counts[quality.rawValue, default: 0])")
        }
        lines.append("")
        lines.append("## Functions")
        for record in source.records.sorted(by: { $0.functionAddress.value < $1.functionAddress.value }) {
            let file = record.generatedFile ?? "(not emitted)"
            lines.append("- \(record.functionAddress.hexString) \(record.recoveredName) — \(record.quality.displayName) — \(file)\(record.generatedLine.map { ":\($0)" } ?? "")")
            for warning in record.warnings {
                lines.append("  - \(warning)")
            }
        }
        lines.append("")
        lines.append("## Diagnostics")
        if source.diagnostics.isEmpty {
            lines.append("None.")
        } else {
            for diag in source.diagnostics {
                lines.append("- [\(diag.severity.rawValue)] \(diag.message)")
            }
        }
        lines.append("")
        lines.append("## Build configuration (inferred)")
        lines.append("- Architectures: \(configuration.architectures.map(\.displayName).joined(separator: ", "))")
        lines.append("- Deployment target: \(configuration.deploymentTarget ?? "not recovered")")
        lines.append("- Install name: \(configuration.installName ?? "not recovered")")
        lines.append("- Optimization: -O\(configuration.optimizationLevel)")
        lines.append("- Output: \(configuration.outputFileName)")
        return lines.joined(separator: "\n") + "\n"
    }

    private static func projectReadme(source: ReconstructedSource, image: BinaryImage,
                                      configuration: BuildConfiguration) -> String {
        var lines: [String] = []
        lines.append("# \(source.libraryName) — Reconstructed Project")
        lines.append("")
        lines.append("Reconstructed from \(image.identity.originalFileName) (\(image.format.displayName), \(image.architecture.displayName)).")
        lines.append("This is a reconstruction, not the original source. Every function carries")
        lines.append("a quality label (Recovered, Reconstructed, Inferred, Partial, Unresolved,")
        lines.append("Unsupported) recorded in Diagnostics/reconstruction-report.md and in")
        lines.append("Mappings/source-map.json, which maps original addresses to files and lines.")
        lines.append("")
        lines.append("## Layout")
        lines.append("")
        lines.append("- `Sources/` — reconstructed C sources, recovered strings, and data blobs.")
        lines.append("- `Headers/` — recovered declarations and the Ghidra type compatibility header.")
        lines.append("- `Assembly/` — functions preserved as verbatim machine code with")
        lines.append("  PC-relative references repaired where the repair rules apply. Edit a")
        lines.append("  function in C by deleting its assembly block and adding a C definition")
        lines.append("  with the same name in `Sources/`.")
        lines.append("- `Mappings/` — address-to-source mappings for navigation and debugging.")
        lines.append("- `Build/` — build configuration, CMakeLists.txt, and build artifacts.")
        lines.append("- `Diagnostics/` — reconstruction report and diagnostics.")
        lines.append("- `Metadata/` — original binary metadata (install name, dependencies, UUID).")
        lines.append("")
        lines.append("## Building")
        lines.append("")
        lines.append("Use Assemble in SwiftCode, or build the SwiftPM package:")
        lines.append("")
        lines.append("```")
        lines.append("swift build -c release")
        lines.append("```")
        lines.append("")
        lines.append("Output file name: \(configuration.outputFileName)")
        lines.append("Target architectures: \(configuration.architectures.map(\.displayName).joined(separator: ", "))")
        lines.append("")
        lines.append("The original binary is never modified. Assemble writes a new library")
        lines.append("and validates its exports against the original before reporting success.")
        return lines.joined(separator: "\n") + "\n"
    }

    private static func originalMetadata(image: BinaryImage) -> [String: Any] {
        var dict: [String: Any] = [:]
        dict["fileName"] = image.identity.originalFileName
        dict["sha256"] = image.identity.sha256
        dict["fileSize"] = image.identity.fileSize
        dict["format"] = image.format.rawValue
        dict["architecture"] = image.architecture.rawValue
        dict["cpu"] = image.cpuIdentifier
        dict["fileType"] = image.fileType
        dict["entryPoint"] = image.entryPoint?.hexString as Any
        dict["isSigned"] = image.isSigned
        dict["isEncrypted"] = image.isEncrypted
        dict["hasDebugInfo"] = image.hasDebugInfo
        dict["buildVersion"] = image.buildVersion as Any
        dict["minOSVersion"] = image.minOSVersion as Any
        dict["uuid"] = image.identity.binaryUUID as Any
        dict["exports"] = image.exports.map(\.name)
        dict["imports"] = image.imports.map { ["name": $0.name, "library": $0.library] }
        dict["dependencies"] = image.dependencies.map(\.path)
        dict["symbols"] = image.symbols.map(\.name)
        return dict
    }
}
