import Foundation



public actor EngineRegistry {
    public static let shared = EngineRegistry()

    private var disassemblers: [any DisassemblerProvider] = []
    private var decompilers: [any DecompilerProvider] = []
    private var analyzers: [any AnalyzerProvider] = []
    private var cachedDescriptors: [EngineDescriptor]?

    public init() {}

    public func register(disassembler: any DisassemblerProvider) {
        disassemblers.removeAll { $0.id == disassembler.id }
        disassemblers.append(disassembler)
        cachedDescriptors = nil
    }

    public func register(decompiler: any DecompilerProvider) {
        decompilers.removeAll { $0.id == decompiler.id }
        decompilers.append(decompiler)
        cachedDescriptors = nil
    }

    public func register(analyzer: any AnalyzerProvider) {
        analyzers.removeAll { $0.id == analyzer.id }
        analyzers.append(analyzer)
        cachedDescriptors = nil
    }

    
    
    
    
    
    
    public func descriptors() async -> [EngineDescriptor] {
        if let cached = cachedDescriptors { return cached }
        var out: [EngineDescriptor] = []
        for d in disassemblers {
            out.append(EngineDescriptor(
                id: d.id, displayName: d.displayName, kind: .disassembler,
                version: d.version, supportedFormats: d.supportedFormats,
                supportedArchitectures: d.supportedArchitectures,
                capabilities: d.capabilities(for: Self.placeholderImage),
                isAvailable: await d.isAvailable()))
        }
        for d in decompilers {
            out.append(EngineDescriptor(
                id: d.id, displayName: d.displayName, kind: .decompiler,
                version: d.version, supportedFormats: d.supportedFormats,
                supportedArchitectures: d.supportedArchitectures,
                capabilities: d.capabilities(for: Self.placeholderImage),
                isAvailable: await d.isAvailable(),
                availabilityDetail: await d.availabilityDetail(),
                isPrimaryDecompiler: d.isPrimary))
        }
        cachedDescriptors = out
        return out
    }

    
    private static var placeholderImage: BinaryImage {
        BinaryImage(identity: BinaryIdentity(sha256: "", originalFileName: "", originalLocation: "",
                                              fileSize: 0, format: .unknown, architecture: .unknown),
                    format: .unknown, architecture: .unknown, cpuIdentifier: "",
                    fileType: "", entryPoint: nil, segments: [], imports: [], exports: [],
                    dependencies: [], symbols: [], strings: [], functionStarts: [],
                    isEncrypted: false, isSigned: false, entitlements: nil,
                    codeSignatureInfo: nil, buildVersion: nil, minOSVersion: nil,
                    hasDebugInfo: false, byteCount: 0,
                    byteProvider: { _, _ in Data() })
    }

    
    
    
    public func resolveDisassembler(for image: BinaryImage,
                                    preferredID: String? = nil) async -> (any DisassemblerProvider)? {
        var candidates: [any DisassemblerProvider] = []
        for provider in disassemblers {
            guard provider.capabilities(for: image).contains(.disassemble)
                && (image.format == .unknown || provider.supportedFormats.isEmpty
                    || provider.supportedFormats.contains(image.format))
                && (image.architecture == .unknown || provider.supportedArchitectures.isEmpty
                    || provider.supportedArchitectures.contains(image.architecture))
            else { continue }
            if await provider.isAvailable() { candidates.append(provider) }
        }
        if let preferredID, let match = candidates.first(where: { $0.id == preferredID }) { return match }
        return candidates.first
    }

    
    public func resolveDecompiler(for image: BinaryImage, required: DecompilerCapabilitiesSet,
                                  preferredID: String? = nil) async -> (any DecompilerProvider)? {
        var capable: [any DecompilerProvider] = []
        for d in decompilers {
            guard d.capabilities(for: image).isSuperset(of: required)
                && (image.format == .unknown || d.supportedFormats.isEmpty || d.supportedFormats.contains(image.format))
                && (image.architecture == .unknown || d.supportedArchitectures.isEmpty || d.supportedArchitectures.contains(image.architecture))
            else { continue }
            if await d.isAvailable() {
                capable.append(d)
            }
        }
        if let preferredID, let match = capable.first(where: { $0.id == preferredID }) { return match }
        return capable.first(where: \.isPrimary) ?? capable.first
    }

    public func allDisassemblers() -> [any DisassemblerProvider] { disassemblers }
    public func allDecompilers() -> [any DecompilerProvider] { decompilers }

    
    public func installDefaults() async {
        
        
    }
}
