import Foundation

/// A binary format parser. Implementations live under Formats/.
public protocol BinaryParser: Sendable {
    var format: BinaryFormat { get }
    /// Returns nil when the bytes are not this format (detection is cheap).
    func matches(header: Data) -> Bool
    /// Parse one slice into the canonical BinaryImage.
    /// `sliceIndex` selects the slice inside universal containers.
    func parse(url: URL, sliceIndex: Int, identity: BinaryIdentity,
               byteProvider: @escaping @Sendable (UInt64, UInt64) throws -> Data) throws -> BinaryImage
    /// Enumerate slices without full parsing (for fat binaries).
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

/// Disassembly backend contract.
public protocol DisassemblerProvider: Sendable {
    var id: String { get }
    var displayName: String { get }
    var version: String? { get }
    var supportedFormats: Set<BinaryFormat> { get }
    var supportedArchitectures: Set<BinaryArchitecture> { get }
    func capabilities(for image: BinaryImage) -> DecompilerCapabilitiesSet
    func isAvailable() async -> Bool
    /// Decode instructions covering [start, end) virtual addresses.
    func disassemble(image: BinaryImage, start: DecompilerAddress, end: DecompilerAddress,
                     progress: (@Sendable (AnalysisProgress) -> Void)?) async throws -> [Instruction]
}

public extension DisassemblerProvider {
    var supportedFormats: Set<BinaryFormat> { [] }
    var supportedArchitectures: Set<BinaryArchitecture> { [] }
}

/// Decompilation backend contract (e.g. Ghidra headless).
public protocol DecompilerProvider: Sendable {
    var id: String { get }
    var displayName: String { get }
    var version: String? { get }
    var isPrimary: Bool { get }
    var supportedFormats: Set<BinaryFormat> { get }
    var supportedArchitectures: Set<BinaryArchitecture> { get }
    func isAvailable() async -> Bool
    /// Human-readable reason when unavailable (shown in UI).
    func availabilityDetail() async -> String
    func capabilities(for image: BinaryImage) -> DecompilerCapabilitiesSet
    func decompile(_ request: DecompilationRequest,
                   progress: (@Sendable (AnalysisProgress) -> Void)?) async throws -> DecompilationResult
    /// Optional batch decompilation for efficiency.
    func decompileBatch(_ requests: [DecompilationRequest],
                        progress: (@Sendable (AnalysisProgress) -> Void)?) async throws -> [DecompilationResult]
}

public extension DecompilerProvider {
    var supportedFormats: Set<BinaryFormat> { [] }
    var supportedArchitectures: Set<BinaryArchitecture> { [] }
}

/// Lightweight analysis backend contract (function discovery, xrefs, strings).
public protocol AnalyzerProvider: Sendable {
    var id: String { get }
    func capabilities(for image: BinaryImage) -> DecompilerCapabilitiesSet
    func isAvailable() async -> Bool
}
