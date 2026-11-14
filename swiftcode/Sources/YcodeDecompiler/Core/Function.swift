import Foundation


public enum AnalysisProvenance: String, Sendable, Codable {
    case formatParser      
    case symbolTable       
    case engine            
    case heuristic         
    case user              
    case aiSuggestion      
}

public struct AnalysisSource: Hashable, Sendable, Codable {
    public var provenance: AnalysisProvenance
    public var engineID: String?
    public var engineVersion: String?
    public var pass: String?
    public var timestamp: Date
    
    public var confidence: Double?

    public init(provenance: AnalysisProvenance, engineID: String? = nil,
                engineVersion: String? = nil, pass: String? = nil,
                timestamp: Date = Date(), confidence: Double? = nil) {
        self.provenance = provenance
        self.engineID = engineID
        self.engineVersion = engineVersion
        self.pass = pass
        self.timestamp = timestamp
        self.confidence = confidence
    }
}


public struct DecompilerFunction: Identifiable, Hashable, Sendable, Codable {
    public enum Kind: String, Sendable, Codable {
        case importedSymbol, exportedSymbol, discovered, entryPoint, userLabel, thunk
    }

    public var id: String                 
    public var address: DecompilerAddress 
    public var endAddress: DecompilerAddress?
    public var size: UInt64
    public var name: String               
    public var originalName: String?      
    public var kind: Kind
    public var callingConvention: String?
    public var returnType: String?
    public var parameters: [String]
    public var localVariables: [String]
    public var callers: [DecompilerAddress]
    public var callees: [DecompilerAddress]
    public var source: AnalysisSource
    
    public var hasPseudocode: Bool
    
    public var hasDisassembly: Bool
    public var isPinned: Bool

    public init(id: String? = nil, address: DecompilerAddress, endAddress: DecompilerAddress? = nil,
                size: UInt64 = 0, name: String, originalName: String? = nil, kind: Kind,
                callingConvention: String? = nil, returnType: String? = nil,
                parameters: [String] = [], localVariables: [String] = [],
                callers: [DecompilerAddress] = [], callees: [DecompilerAddress] = [],
                source: AnalysisSource, hasPseudocode: Bool = false, hasDisassembly: Bool = false,
                isPinned: Bool = false) {
        self.id = id ?? "fn-\(address.hexString)"
        self.address = address
        self.endAddress = endAddress
        self.size = size
        self.name = name
        self.originalName = originalName
        self.kind = kind
        self.callingConvention = callingConvention
        self.returnType = returnType
        self.parameters = parameters
        self.localVariables = localVariables
        self.callers = callers
        self.callees = callees
        self.source = source
        self.hasPseudocode = hasPseudocode
        self.hasDisassembly = hasDisassembly
        self.isPinned = isPinned
    }

    public var displayName: String { name.isEmpty ? address.description : name }
}
