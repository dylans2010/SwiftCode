import Foundation

public enum DecompilerError: Error, LocalizedError, Sendable {
    case unsupportedFormat(String)
    case unsupportedArchitecture(BinaryArchitecture)
    case malformedBinary(String)
    case truncatedFile(String)
    case unmappedAddress(String)
    case engineUnavailable(String)
    case engineFailure(String)
    case engineTimeout(String)
    case engineCancelled(String)
    case unsupportedCapability(String)
    case invalidRequest(String)
    case persistenceFailure(String)
    case permissionDenied(String)
    case resourceLimitExceeded(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let d): return "Unsupported binary format: \(d)"
        case .unsupportedArchitecture(let a): return "Unsupported architecture: \(a.displayName)"
        case .malformedBinary(let d): return "Malformed binary: \(d)"
        case .truncatedFile(let d): return "Truncated file: \(d)"
        case .unmappedAddress(let a): return "Address not mapped in any segment: \(a)"
        case .engineUnavailable(let d): return "Analysis engine unavailable: \(d)"
        case .engineFailure(let d): return "Analysis engine failure: \(d)"
        case .engineTimeout(let d): return "Analysis engine timed out: \(d)"
        case .engineCancelled(let d): return "Analysis cancelled: \(d)"
        case .unsupportedCapability(let d): return "Unsupported capability: \(d)"
        case .invalidRequest(let d): return "Invalid request: \(d)"
        case .persistenceFailure(let d): return "Persistence failure: \(d)"
        case .permissionDenied(let d): return "Permission denied: \(d)"
        case .resourceLimitExceeded(let d): return "Resource limit exceeded: \(d)"
        }
    }
}

/// Honest progress reporting. `fraction` is nil when the backend cannot
/// provide a real percentage — the UI shows stage text instead.
public struct AnalysisProgress: Sendable {
    public enum Stage: String, Sendable, Codable, CaseIterable {
        case idle, importing, parsing, detectingArchitecture
        case discoveringFunctions, buildingSymbols, disassembling
        case decompiling, buildingReferences, extractingStrings
        case persisting, completed, failed, cancelled
    }

    public var stage: Stage
    /// Real completion fraction in [0,1]; nil = indeterminate.
    public var fraction: Double?
    public var message: String
    public var itemsProcessed: Int
    public var itemsTotal: Int?

    public init(stage: Stage, fraction: Double? = nil, message: String = "",
                itemsProcessed: Int = 0, itemsTotal: Int? = nil) {
        self.stage = stage
        self.fraction = fraction
        self.message = message
        self.itemsProcessed = itemsProcessed
        self.itemsTotal = itemsTotal
    }

    public static let idle = AnalysisProgress(stage: .idle)
}

public struct AnalysisConfiguration: Sendable, Codable {
    /// Whether to run the full static-analysis pipeline after parsing.
    public var autoAnalyze: Bool = true
    /// Maximum functions to decompile during bulk decompilation (0 = unlimited).
    public var maxBulkDecompileFunctions: Int = 0
    /// Whether to extract strings during analysis.
    public var extractStrings: Bool = true
    /// Whether to build cross-references.
    public var buildReferences: Bool = true
    /// Preferred decompiler backend id; nil = automatic capability resolution.
    public var preferredDecompilerID: String?
    /// Preferred disassembler backend id; nil = automatic.
    public var preferredDisassemblerID: String?
    /// Analysis timeout per engine request, seconds.
    public var engineTimeoutSeconds: Int = 600
    /// Working directory for engine temp files.
    public var engineTempDirectory: String?

    public init() {}
}

/// Static capability declarations for the Decompiler subsystem.
public enum DecompilerCapabilities {
    public static let subsystemName = "Decompiler"
    public static let assistantName = "Decompile Assist"
    public static let projectFileExtension = "scdecomp"
    public static let parserVersion = "1.0.0"
    public static let projectSchemaVersion = 1
    public static let databaseSchemaVersion = 1
}
