import Foundation

public struct BinarySymbol: Identifiable, Hashable, Sendable, Codable {
    public enum Kind: String, Sendable, Codable {
        case local, global, external, undefined, absolute, common
    }

    public var id: String { "sym-\(address?.hexString ?? name)-\(name)" }
    public var name: String                // original (possibly mangled) name
    public var demangledName: String?
    public var address: DecompilerAddress?
    public var size: UInt64
    public var kind: Kind
    /// User-assigned display name; nil means use demangled/original.
    public var userName: String?
    /// Original name is preserved even when userName is set (rename is reversible).
    public var library: String?
    public var source: AnalysisSource

    public init(name: String, demangledName: String? = nil, address: DecompilerAddress? = nil,
                size: UInt64 = 0, kind: Kind, userName: String? = nil,
                library: String? = nil, source: AnalysisSource) {
        self.name = name
        self.demangledName = demangledName
        self.address = address
        self.size = size
        self.kind = kind
        self.userName = userName
        self.library = library
        self.source = source
    }

    public var effectiveName: String { userName ?? demangledName ?? name }
}

/// A cross-reference between two addresses.
public struct CrossReference: Identifiable, Hashable, Sendable, Codable {
    public enum Kind: String, Sendable, Codable {
        case call, jump, branch, data, string, symbol, section, memory
    }

    public var id: String { "xref-\(source.hexString)-\(destination.hexString)-\(kind.rawValue)" }
    public var source: DecompilerAddress
    public var destination: DecompilerAddress
    public var kind: Kind
    public var sourceFunction: DecompilerAddress?
    public var destinationFunction: DecompilerAddress?
    public var provenance: AnalysisSource

    public init(source: DecompilerAddress, destination: DecompilerAddress, kind: Kind,
                sourceFunction: DecompilerAddress? = nil,
                destinationFunction: DecompilerAddress? = nil,
                provenance: AnalysisSource) {
        self.source = source
        self.destination = destination
        self.kind = kind
        self.sourceFunction = sourceFunction
        self.destinationFunction = destinationFunction
        self.provenance = provenance
    }
}

/// Recovered type information with provenance preserved.
public struct TypeInfo: Identifiable, Hashable, Sendable, Codable {
    public enum Kind: String, Sendable, Codable {
        case primitive, pointer, array, structure, union, enumeration, function, typeDef, unknown, backendSpecific
    }

    public var id: String
    public var name: String
    public var kind: Kind
    public var size: UInt64?
    public var fields: [Field]
    public var underlyingType: String?
    /// Original inferred spelling, kept when the user overrides the name.
    public var originalInferred: String?
    public var userEdited: Bool
    public var provenance: AnalysisSource

    public struct Field: Hashable, Sendable, Codable {
        public var name: String
        public var typeName: String
        public var offset: UInt64
    }

    public init(id: String? = nil, name: String, kind: Kind, size: UInt64? = nil,
                fields: [Field] = [], underlyingType: String? = nil,
                originalInferred: String? = nil, userEdited: Bool = false,
                provenance: AnalysisSource) {
        self.id = id ?? "type-\(name)"
        self.name = name
        self.kind = kind
        self.size = size
        self.fields = fields
        self.underlyingType = underlyingType
        self.originalInferred = originalInferred
        self.userEdited = userEdited
        self.provenance = provenance
    }
}
