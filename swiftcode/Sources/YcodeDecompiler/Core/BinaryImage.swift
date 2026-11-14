import Foundation


public struct BinaryIdentity: Hashable, Sendable, Codable {
    public var sha256: String
    public var originalFileName: String
    public var originalLocation: String
    public var fileSize: Int64
    public var format: BinaryFormat
    public var architecture: BinaryArchitecture
    
    public var sliceIndex: Int
    public var sliceName: String
    
    public var binaryUUID: String?
    public var importedAt: Date
    public var parserVersion: String

    public init(sha256: String, originalFileName: String, originalLocation: String,
                fileSize: Int64, format: BinaryFormat, architecture: BinaryArchitecture,
                sliceIndex: Int = 0, sliceName: String = "",
                binaryUUID: String? = nil, importedAt: Date = Date(),
                parserVersion: String = DecompilerCapabilities.parserVersion) {
        self.sha256 = sha256
        self.originalFileName = originalFileName
        self.originalLocation = originalLocation
        self.fileSize = fileSize
        self.format = format
        self.architecture = architecture
        self.sliceIndex = sliceIndex
        self.sliceName = sliceName
        self.binaryUUID = binaryUUID
        self.importedAt = importedAt
        self.parserVersion = parserVersion
    }

    
    public var stableID: String { "\(sha256.prefix(16))-s\(sliceIndex)" }
}

public struct BinarySectionInfo: Hashable, Sendable, Codable {
    public var name: String
    public var segment: String
    public var address: DecompilerAddress   
    public var size: UInt64
    public var fileOffset: UInt64
    public var flags: UInt32
    
    public var isExecutable: Bool
    public var isWritable: Bool
    public var containsStrings: Bool
}

public struct BinarySegmentInfo: Hashable, Sendable, Codable {
    public var name: String
    public var vmAddress: UInt64
    public var vmSize: UInt64
    public var fileOffset: UInt64
    public var fileSize: UInt64
    public var maxProtection: Int
    public var initialProtection: Int
    public var sections: [BinarySectionInfo]
    public var isExecutable: Bool { maxProtection & 4 != 0 || name.contains("TEXT") || name == "__TEXT" }
}

public struct BinaryImport: Hashable, Sendable, Codable {
    public var name: String
    public var library: String
    public var address: DecompilerAddress?
    public var isWeak: Bool
}

public struct BinaryExport: Hashable, Sendable, Codable {
    public var name: String
    public var address: DecompilerAddress
    public var kind: Kind
    public enum Kind: String, Sendable, Codable { case symbol, function, object, unknown }
}

public struct BinaryDependency: Hashable, Sendable, Codable {
    public var path: String
    public var kind: String   
    public var currentVersion: String?
    public var compatibilityVersion: String?
}


public struct BinaryImage: Sendable {
    public var identity: BinaryIdentity
    public var format: BinaryFormat
    public var architecture: BinaryArchitecture
    public var cpuIdentifier: String
    public var fileType: String
    public var entryPoint: DecompilerAddress?
    public var segments: [BinarySegmentInfo]
    public var imports: [BinaryImport]
    public var exports: [BinaryExport]
    public var dependencies: [BinaryDependency]
    public var symbols: [BinarySymbol]
    public var strings: [BinaryString]
    public var functionStarts: [DecompilerAddress]
    public var isEncrypted: Bool
    public var isSigned: Bool
    public var entitlements: String?
    public var codeSignatureInfo: String?
    public var installName: String?
    public var runpaths: [String] = []
    public var buildVersion: String?
    public var minOSVersion: String?
    
    
    
    
    public var targetPlatform: String?
    
    
    
    
    public var containerOffset: UInt64
    public var hasDebugInfo: Bool
    
    
    public var byteCount: Int64
    public var byteProvider: @Sendable (UInt64, UInt64) throws -> Data

    public init(identity: BinaryIdentity, format: BinaryFormat, architecture: BinaryArchitecture,
                cpuIdentifier: String, fileType: String,
                entryPoint: DecompilerAddress?, segments: [BinarySegmentInfo],
                imports: [BinaryImport], exports: [BinaryExport],
                dependencies: [BinaryDependency], symbols: [BinarySymbol],
                strings: [BinaryString], functionStarts: [DecompilerAddress],
                isEncrypted: Bool, isSigned: Bool, entitlements: String?,
                codeSignatureInfo: String?, buildVersion: String?, minOSVersion: String?,
                hasDebugInfo: Bool, byteCount: Int64,
                byteProvider: @escaping @Sendable (UInt64, UInt64) throws -> Data,
                targetPlatform: String? = nil, containerOffset: UInt64 = 0) {
        self.identity = identity
        self.format = format
        self.architecture = architecture
        self.cpuIdentifier = cpuIdentifier
        self.fileType = fileType
        self.entryPoint = entryPoint
        self.segments = segments
        self.imports = imports
        self.exports = exports
        self.dependencies = dependencies
        self.symbols = symbols
        self.strings = strings
        self.functionStarts = functionStarts
        self.isEncrypted = isEncrypted
        self.isSigned = isSigned
        self.entitlements = entitlements
        self.codeSignatureInfo = codeSignatureInfo
        self.buildVersion = buildVersion
        self.minOSVersion = minOSVersion
        self.targetPlatform = targetPlatform
        self.containerOffset = containerOffset
        self.hasDebugInfo = hasDebugInfo
        self.byteCount = byteCount
        self.byteProvider = byteProvider
    }

    
    public var executableSections: [BinarySectionInfo] {
        segments.flatMap(\.sections).filter(\.isExecutable).sorted {
            $0.address.value < $1.address.value
        }
    }

    
    public func fileOffset(forVirtualAddress address: UInt64) -> UInt64? {
        for seg in segments {
            guard address >= seg.vmAddress, address < seg.vmAddress + seg.vmSize else { continue }
            let delta = address - seg.vmAddress
            guard delta < seg.fileSize else { return nil }
            return seg.fileOffset + delta
        }
        return nil
    }

    
    public func bytes(virtualAddress: UInt64, length: Int) throws -> Data {
        guard let off = fileOffset(forVirtualAddress: virtualAddress) else {
            throw DecompilerError.unmappedAddress(String(format: "0x%llx", virtualAddress))
        }
        return try byteProvider(off, UInt64(length))
    }

    
    public func bytes(fileOffset: UInt64, length: Int) throws -> Data {
        try byteProvider(fileOffset, UInt64(length))
    }
}

public struct BinaryString: Hashable, Sendable, Codable {
    public var text: String
    public var address: DecompilerAddress   
    public var fileOffset: UInt64
    public var encoding: EncodingKind
    public var isReferenced: Bool
    public enum EncodingKind: String, Sendable, Codable { case ascii, utf8, utf16LE, utf16BE }
}
