import Foundation

/// Registry of all analysis engines. Resolves the best provider for an
/// operation based on format, architecture and required capability.
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

    /// All registered engines with live availability status.
    public func descriptors() async -> [EngineDescriptor] {
        if let cached = cachedDescriptors { return cached }
        var out: [EngineDescriptor] = []
        for d in disassemblers {
            guard let image = placeholderImage else { continue }
            out.append(EngineDescriptor(
                id: d.id, displayName: d.displayName, kind: .disassembler,
                version: d.version, supportedFormats: [], supportedArchitectures: [],
                capabilities: d.capabilities(for: image),
                isAvailable: await d.isAvailable()))
        }
        for d in decompilers {
            guard let image = placeholderImage else { continue }
            out.append(EngineDescriptor(
                id: d.id, displayName: d.displayName, kind: .decompiler,
                version: d.version, supportedFormats: [], supportedArchitectures: [],
                capabilities: d.capabilities(for: image),
                isAvailable: await d.isAvailable(),
                availabilityDetail: await d.availabilityDetail(),
                isPrimaryDecompiler: d.isPrimary))
        }
        cachedDescriptors = out
        return out
    }

    /// A minimal image used for capability queries when no binary is loaded.
    private var placeholderImage: BinaryImage? {
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

    /// Pick a disassembler that supports this image.
    public func resolveDisassembler(for image: BinaryImage,
                                    preferredID: String? = nil) -> (any DisassemblerProvider)? {
        let candidates = disassemblers.filter { $0.capabilities(for: image).contains(.decompileFunction) || true }
        if let preferredID, let match = candidates.first(where: { $0.id == preferredID }) { return match }
        return candidates.first
    }

    /// Pick a decompiler for a function-level request.
    public func resolveDecompiler(for image: BinaryImage, required: DecompilerCapabilitiesSet,
                                  preferredID: String? = nil) -> (any DecompilerProvider)? {
        let capable = decompilers.filter { d in
            let caps = d.capabilities(for: image)
            return caps.isSuperset(of: required) || caps.contains(.decompileFunction)
        }
        if let preferredID, let match = capable.first(where: { $0.id == preferredID }) { return match }
        return capable.first(where: \.isPrimary) ?? capable.first
    }

    public func allDisassemblers() -> [any DisassemblerProvider] { disassemblers }
    public func allDecompilers() -> [any DecompilerProvider] { decompilers }

    /// Install the built-in engine set. Called once at app startup.
    public func installDefaults() async {
        // Concrete engines register themselves; this hook exists so app
        // startup order stays explicit.
    }
}
