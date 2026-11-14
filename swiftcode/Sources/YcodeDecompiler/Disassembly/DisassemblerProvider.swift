import Foundation






public enum DisassemblerBackends {

    
    
    
    
    public static func all() -> [any DisassemblerProvider] {
        [ObjDumpDisassembler(), OtoolDisassembler()]
    }

    
    
    public static func registerDefaults() async {
        for provider in all() {
            await EngineRegistry.shared.register(disassembler: provider)
        }
    }
}
