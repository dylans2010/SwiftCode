import Foundation

public enum ReconstructionQuality: String, Sendable, Codable, CaseIterable {
    case recovered
    case reconstructed
    case inferred
    case partial
    case unresolved
    case unsupported

    public var displayName: String {
        switch self {
        case .recovered: return "Recovered"
        case .reconstructed: return "Reconstructed"
        case .inferred: return "Inferred"
        case .partial: return "Partial"
        case .unresolved: return "Unresolved"
        case .unsupported: return "Unsupported"
        }
    }

    public var explanation: String {
        switch self {
        case .recovered: return "Directly recovered from retained metadata, symbols, or debug information."
        case .reconstructed: return "Generated from strong structural and semantic evidence."
        case .inferred: return "Generated from partial evidence or type inference."
        case .partial: return "Only part of the original construct could be reconstructed."
        case .unresolved: return "Insufficient evidence to produce a meaningful implementation."
        case .unsupported: return "The current toolchain cannot reliably analyze this construct."
        }
    }
}

public enum SourceLanguage: String, Sendable, Codable, CaseIterable {
    case c
    case cpp
    case objectiveC
    case objectiveCpp
    case swift
    case rust
    case go
    case java
    case csharp
    case kotlin
    case assembly
    case unknown

    public var displayName: String {
        switch self {
        case .c: return "C"
        case .cpp: return "C++"
        case .objectiveC: return "Objective-C"
        case .objectiveCpp: return "Objective-C++"
        case .swift: return "Swift"
        case .rust: return "Rust"
        case .go: return "Go"
        case .java: return "Java"
        case .csharp: return "C#"
        case .kotlin: return "Kotlin"
        case .assembly: return "Assembly"
        case .unknown: return "Unknown"
        }
    }

    public var fileExtension: String {
        switch self {
        case .c: return "c"
        case .cpp: return "cpp"
        case .objectiveC: return "m"
        case .objectiveCpp: return "mm"
        case .swift: return "swift"
        case .rust: return "rs"
        case .go: return "go"
        case .java: return "java"
        case .csharp: return "cs"
        case .kotlin: return "kt"
        case .assembly: return "s"
        case .unknown: return "c"
        }
    }
}

public struct ReconstructionRecord: Sendable, Codable, Identifiable {
    public var id: String
    public var functionAddress: DecompilerAddress
    public var originalName: String?
    public var recoveredName: String
    public var inferredName: String?
    public var language: SourceLanguage
    public var architecture: BinaryArchitecture
    public var signature: String?
    public var returnType: String?
    public var parameters: [String]
    public var callingConvention: String?
    public var localVariables: [String]
    public var quality: ReconstructionQuality
    public var provenance: AnalysisSource
    public var generatedFile: String?
    public var generatedLine: Int?
    public var instructionAddresses: [UInt64]
    public var dependencies: [String]
    public var unresolvedReferences: [String]
    public var warnings: [String]
    public var engineID: String?
    public var hasPseudocode: Bool
    public var hasAssemblyFallback: Bool

    public init(id: String? = nil, functionAddress: DecompilerAddress, originalName: String? = nil,
                recoveredName: String, inferredName: String? = nil, language: SourceLanguage,
                architecture: BinaryArchitecture, signature: String? = nil, returnType: String? = nil,
                parameters: [String] = [], callingConvention: String? = nil, localVariables: [String] = [],
                quality: ReconstructionQuality, provenance: AnalysisSource, generatedFile: String? = nil,
                generatedLine: Int? = nil, instructionAddresses: [UInt64] = [], dependencies: [String] = [],
                unresolvedReferences: [String] = [], warnings: [String] = [], engineID: String? = nil,
                hasPseudocode: Bool = false, hasAssemblyFallback: Bool = false) {
        self.id = id ?? "rec-\(functionAddress.hexString)"
        self.functionAddress = functionAddress
        self.originalName = originalName
        self.recoveredName = recoveredName
        self.inferredName = inferredName
        self.language = language
        self.architecture = architecture
        self.signature = signature
        self.returnType = returnType
        self.parameters = parameters
        self.callingConvention = callingConvention
        self.localVariables = localVariables
        self.quality = quality
        self.provenance = provenance
        self.generatedFile = generatedFile
        self.generatedLine = generatedLine
        self.instructionAddresses = instructionAddresses
        self.dependencies = dependencies
        self.unresolvedReferences = unresolvedReferences
        self.warnings = warnings
        self.engineID = engineID
        self.hasPseudocode = hasPseudocode
        self.hasAssemblyFallback = hasAssemblyFallback
    }
}

public struct ReconstructionDiagnostic: Sendable, Codable {
    public enum Severity: String, Sendable, Codable { case info, warning, error }
    public var severity: Severity
    public var message: String
    public var functionAddress: DecompilerAddress?
    public var file: String?
    public var line: Int?

    public init(severity: Severity, message: String, functionAddress: DecompilerAddress? = nil,
                file: String? = nil, line: Int? = nil) {
        self.severity = severity
        self.message = message
        self.functionAddress = functionAddress
        self.file = file
        self.line = line
    }
}

public struct GeneratedSourceFile: Sendable, Codable {
    public var relativePath: String
    public var contents: String
    public var language: SourceLanguage
    public var quality: ReconstructionQuality

    public init(relativePath: String, contents: String, language: SourceLanguage, quality: ReconstructionQuality) {
        self.relativePath = relativePath
        self.contents = contents
        self.language = language
        self.quality = quality
    }
}

public struct ReconstructedSource: Sendable {
    public var libraryName: String
    public var language: SourceLanguage
    public var records: [ReconstructionRecord]
    public var files: [GeneratedSourceFile]
    public var diagnostics: [ReconstructionDiagnostic]
    public var sourceMap: SourceMapping
    public var exportedNames: [String]
    public var unresolvedImports: [String]
    public var enginesUsed: [String]
    public var decompilerAvailable: Bool

    public init(libraryName: String, language: SourceLanguage, records: [ReconstructionRecord],
                files: [GeneratedSourceFile], diagnostics: [ReconstructionDiagnostic],
                sourceMap: SourceMapping, exportedNames: [String], unresolvedImports: [String],
                enginesUsed: [String], decompilerAvailable: Bool) {
        self.libraryName = libraryName
        self.language = language
        self.records = records
        self.files = files
        self.diagnostics = diagnostics
        self.sourceMap = sourceMap
        self.exportedNames = exportedNames
        self.unresolvedImports = unresolvedImports
        self.enginesUsed = enginesUsed
        self.decompilerAvailable = decompilerAvailable
    }
}

public enum LanguageIdentification {
    public static func identify(image: BinaryImage, function: DecompilerFunction? = nil) -> SourceLanguage {
        let sectionNames = image.segments.flatMap(\.sections).map { $0.name }
        let segmentNames = image.segments.map(\.name)
        let names = image.symbols.map(\.name) + image.exports.map(\.name) + image.imports.map(\.name)
        if let function {
            let fnName = function.originalName ?? function.name
            let fnLanguage = identifySymbol(fnName, sectionNames: sectionNames)
            if fnLanguage != .unknown && fnLanguage != .c { return fnLanguage }
        }
        if sectionNames.contains(where: { $0.hasPrefix("__objc_") || $0 == "__objc_classlist" })
            || names.contains(where: { $0.hasPrefix("OBJC_CLASS_$_") || $0.hasPrefix("_OBJC_") }) {
            return .objectiveC
        }
        if sectionNames.contains(where: { $0.hasPrefix("_swift5") || $0.hasPrefix("__swift5") })
            || names.contains(where: { $0.hasPrefix("$s") || $0.hasPrefix("_$s") }) {
            return .swift
        }
        if names.contains(where: { $0.hasPrefix("_Z") || $0.hasPrefix("__Z") }) {
            return segmentNames.contains("__objc_classlist") ? .objectiveCpp : .cpp
        }
        if names.contains(where: { $0.hasPrefix("_R") || $0.contains("__rust") }) {
            return .rust
        }
        if names.contains(where: { $0.hasPrefix("runtime.") || $0.hasPrefix("go.") })
            || sectionNames.contains("__gosymtab") {
            return .go
        }
        if sectionNames.contains(where: { $0.hasPrefix("__text") }) {
            return .c
        }
        return .unknown
    }

    public static func identifySymbol(_ name: String, sectionNames: [String] = []) -> SourceLanguage {
        if name.hasPrefix("$s") || name.hasPrefix("_$s") || name.hasPrefix("_T0") || name.hasPrefix("_T") {
            return .swift
        }
        if name.hasPrefix("OBJC_CLASS_$_") || name.hasPrefix("_OBJC_") || name.hasPrefix("OBJC_") {
            return .objectiveC
        }
        if name.hasPrefix("_Z") || name.hasPrefix("__Z") {
            return .cpp
        }
        if name.hasPrefix("_R") || name.hasPrefix("__R") {
            return .rust
        }
        if name.hasPrefix("runtime.") || name.hasPrefix("main.") {
            return .go
        }
        return .unknown
    }
}
