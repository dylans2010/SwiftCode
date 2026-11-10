import Foundation

/// What an analysis/decompiler backend can do for a given slice.
public struct DecompilerCapabilitiesSet: OptionSet, Sendable, Codable, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let decompileFunction = DecompilerCapabilitiesSet(rawValue: 1 << 0)
    public static let decompileBatch = DecompilerCapabilitiesSet(rawValue: 1 << 1)
    public static let functionDiscovery = DecompilerCapabilitiesSet(rawValue: 1 << 2)
    public static let typeRecovery = DecompilerCapabilitiesSet(rawValue: 1 << 3)
    public static let crossReferences = DecompilerCapabilitiesSet(rawValue: 1 << 4)
    public static let controlFlowGraph = DecompilerCapabilitiesSet(rawValue: 1 << 5)
    public static let callGraph = DecompilerCapabilitiesSet(rawValue: 1 << 6)
    public static let pcode = DecompilerCapabilitiesSet(rawValue: 1 << 7)
}

/// A registered analysis engine (decompiler/disassembler backend).
public struct EngineDescriptor: Identifiable, Hashable, Sendable {
    public var id: String
    public var displayName: String
    public var kind: Kind
    public var version: String?
    public var supportedFormats: Set<BinaryFormat>
    public var supportedArchitectures: Set<BinaryArchitecture>
    public var capabilities: DecompilerCapabilitiesSet
    public var isAvailable: Bool
    public var availabilityDetail: String
    /// True for the primary recommended decompiler.
    public var isPrimaryDecompiler: Bool

    public enum Kind: String, Sendable, Codable { case decompiler, disassembler, analyzer }

    public init(id: String, displayName: String, kind: Kind, version: String? = nil,
                supportedFormats: Set<BinaryFormat>, supportedArchitectures: Set<BinaryArchitecture>,
                capabilities: DecompilerCapabilitiesSet, isAvailable: Bool,
                availabilityDetail: String = "", isPrimaryDecompiler: Bool = false) {
        self.id = id
        self.displayName = displayName
        self.kind = kind
        self.version = version
        self.supportedFormats = supportedFormats
        self.supportedArchitectures = supportedArchitectures
        self.capabilities = capabilities
        self.isAvailable = isAvailable
        self.availabilityDetail = availabilityDetail
        self.isPrimaryDecompiler = isPrimaryDecompiler
    }
}

public struct DecompilationRequest: Sendable {
    public var functionAddress: DecompilerAddress
    public var functionName: String?
    public var imagePath: String
    public var architecture: BinaryArchitecture
    public var format: BinaryFormat
    public var options: [String: String]

    public init(functionAddress: DecompilerAddress, functionName: String?, imagePath: String,
                architecture: BinaryArchitecture, format: BinaryFormat,
                options: [String: String] = [:]) {
        self.functionAddress = functionAddress
        self.functionName = functionName
        self.imagePath = imagePath
        self.architecture = architecture
        self.format = format
        self.options = options
    }
}

/// Structured result of decompiling one function.
public struct DecompilationResult: Sendable, Codable {
    public var functionAddress: DecompilerAddress
    public var functionName: String
    /// C-like pseudocode text.
    public var pseudocode: String
    /// Backend-specific signature line.
    public var signature: String?
    public var parameters: [String]
    public var returnType: String?
    public var localVariables: [String]
    /// Address-to-line mapping: virtual address → pseudocode line number.
    public var addressLineMap: [UInt64: Int]
    /// Backend diagnostics / warnings.
    public var warnings: [String]
    public var engineID: String
    public var engineVersion: String?
    public var rawBackendOutput: String?

    public init(functionAddress: DecompilerAddress, functionName: String, pseudocode: String,
                signature: String? = nil, parameters: [String] = [], returnType: String? = nil,
                localVariables: [String] = [], addressLineMap: [UInt64: Int] = [:],
                warnings: [String] = [], engineID: String, engineVersion: String? = nil,
                rawBackendOutput: String? = nil) {
        self.functionAddress = functionAddress
        self.functionName = functionName
        self.pseudocode = pseudocode
        self.signature = signature
        self.parameters = parameters
        self.returnType = returnType
        self.localVariables = localVariables
        self.addressLineMap = addressLineMap
        self.warnings = warnings
        self.engineID = engineID
        self.engineVersion = engineVersion
        self.rawBackendOutput = rawBackendOutput
    }
}
