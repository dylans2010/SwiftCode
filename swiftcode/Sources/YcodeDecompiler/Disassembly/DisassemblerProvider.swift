import Foundation

/// Registry helper that vends the built-in disassembler backends.
///
/// Currently ships `ObjDumpDisassembler` (LLVM `llvm-objdump`); additional
/// backends register themselves through `EngineRegistry` and appear here via
/// `EngineRegistry.shared.allDisassemblers()`.
public enum DisassemblerBackends {

    /// All disassembler providers known to this build, in preference order.
    /// `ObjDumpDisassembler` precedes `OtoolDisassembler` so Mach-O images
    /// get whole-container coverage (stubs included); otool is the fallback
    /// for environments without an LLVM toolchain.
    public static func all() -> [any DisassemblerProvider] {
        [ObjDumpDisassembler(), OtoolDisassembler()]
    }

    /// Register every built-in disassembler with the shared registry.
    /// Idempotent — `EngineRegistry.register` deduplicates by engine id.
    public static func registerDefaults() async {
        for provider in all() {
            await EngineRegistry.shared.register(disassembler: provider)
        }
    }
}
