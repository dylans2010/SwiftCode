import Foundation


public protocol BinaryParser: Sendable {
    var format: BinaryFormat { get }
    
    func matches(header: Data) -> Bool
    
    
    func parse(url: URL, sliceIndex: Int, identity: BinaryIdentity,
               byteProvider: @escaping @Sendable (UInt64, UInt64) throws -> Data) throws -> BinaryImage
    
    func detectSlices(url: URL) throws -> [SliceDescriptor]
}

public struct SliceDescriptor: Hashable, Sendable {
    public var index: Int
    public var architecture: BinaryArchitecture
    public var cpuIdentifier: String
    public var offset: UInt64
    public var size: UInt64
    public var name: String

    public init(index: Int, architecture: BinaryArchitecture, cpuIdentifier: String,
                offset: UInt64, size: UInt64, name: String) {
        self.index = index; self.architecture = architecture
        self.cpuIdentifier = cpuIdentifier; self.offset = offset
        self.size = size; self.name = name
    }
}


public protocol DisassemblerProvider: Sendable {
    var id: String { get }
    var displayName: String { get }
    var version: String? { get }
    var supportedFormats: Set<BinaryFormat> { get }
    var supportedArchitectures: Set<BinaryArchitecture> { get }
    func capabilities(for image: BinaryImage) -> DecompilerCapabilitiesSet
    func isAvailable() async -> Bool
    
    func disassemble(image: BinaryImage, start: DecompilerAddress, end: DecompilerAddress,
                     progress: (@Sendable (AnalysisProgress) -> Void)?) async throws -> [Instruction]
}

public extension DisassemblerProvider {
    var supportedFormats: Set<BinaryFormat> { [] }
    var supportedArchitectures: Set<BinaryArchitecture> { [] }
}


public protocol DecompilerProvider: Sendable {
    var id: String { get }
    var displayName: String { get }
    var version: String? { get }
    var isPrimary: Bool { get }
    var supportedFormats: Set<BinaryFormat> { get }
    var supportedArchitectures: Set<BinaryArchitecture> { get }
    func isAvailable() async -> Bool
    
    func availabilityDetail() async -> String
    func capabilities(for image: BinaryImage) -> DecompilerCapabilitiesSet
    func decompile(_ request: DecompilationRequest,
                   progress: (@Sendable (AnalysisProgress) -> Void)?) async throws -> DecompilationResult
    
    func decompileBatch(_ requests: [DecompilationRequest],
                        progress: (@Sendable (AnalysisProgress) -> Void)?) async throws -> [DecompilationResult]
}

public extension DecompilerProvider {
    var supportedFormats: Set<BinaryFormat> { [] }
    var supportedArchitectures: Set<BinaryArchitecture> { [] }
}


public protocol AnalyzerProvider: Sendable {
    var id: String { get }
    func capabilities(for image: BinaryImage) -> DecompilerCapabilitiesSet
    func isAvailable() async -> Bool
}
