import Foundation

/// Thin facade over `EngineRegistry` for decompiler (and disassembler)
/// providers, giving UI layers a stable entry point that does not depend on
/// registry internals.
public enum DecompilerRegistry {

    /// All registered decompiler providers.
    public static func decompilers() async -> [any DecompilerProvider] {
        await EngineRegistry.shared.allDecompilers()
    }

    /// All registered disassembler providers.
    public static func disassemblers() async -> [any DisassemblerProvider] {
        await EngineRegistry.shared.allDisassemblers()
    }

    /// Live engine descriptors (availability, versions, capabilities).
    public static func descriptors() async -> [EngineDescriptor] {
        await EngineRegistry.shared.descriptors()
    }

    /// Resolve the best decompiler for a binary slice.
    public static func resolveDecompiler(
        for image: BinaryImage,
        required: DecompilerCapabilitiesSet = [.decompileFunction],
        preferredID: String? = nil
    ) async -> (any DecompilerProvider)? {
        await EngineRegistry.shared.resolveDecompiler(
            for: image, required: required, preferredID: preferredID)
    }

    /// Resolve the best disassembler for a binary slice.
    public static func resolveDisassembler(
        for image: BinaryImage,
        preferredID: String? = nil
    ) async -> (any DisassemblerProvider)? {
        await EngineRegistry.shared.resolveDisassembler(
            for: image, preferredID: preferredID)
    }
}
