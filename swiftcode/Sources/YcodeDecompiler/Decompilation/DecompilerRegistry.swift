import Foundation




public enum DecompilerRegistry {

    
    public static func decompilers() async -> [any DecompilerProvider] {
        await EngineRegistry.shared.allDecompilers()
    }

    
    public static func disassemblers() async -> [any DisassemblerProvider] {
        await EngineRegistry.shared.allDisassemblers()
    }

    
    public static func descriptors() async -> [EngineDescriptor] {
        await EngineRegistry.shared.descriptors()
    }

    
    public static func resolveDecompiler(
        for image: BinaryImage,
        required: DecompilerCapabilitiesSet = [.decompileFunction],
        preferredID: String? = nil
    ) async -> (any DecompilerProvider)? {
        await EngineRegistry.shared.resolveDecompiler(
            for: image, required: required, preferredID: preferredID)
    }

    
    public static func resolveDisassembler(
        for image: BinaryImage,
        preferredID: String? = nil
    ) async -> (any DisassemblerProvider)? {
        await EngineRegistry.shared.resolveDisassembler(
            for: image, preferredID: preferredID)
    }
}
