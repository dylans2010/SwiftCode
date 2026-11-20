import Foundation






public enum EngineBootstrap {

    public static func installDefaults() async {
        let registry = EngineRegistry.shared
        
        
        
        await registry.register(disassembler: ObjDumpDisassembler())
        await registry.register(disassembler: OtoolDisassembler())
        await registry.register(decompiler: GhidraDecompiler())
        await registry.register(decompiler: AngrDecompiler())
        await registry.register(decompiler: NativeStructuralDecompiler())
    }
}
