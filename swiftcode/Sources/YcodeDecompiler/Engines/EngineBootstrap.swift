import Foundation

/// Installs the built-in analysis engines into `EngineRegistry.shared`.
///
/// Call once during application startup, before any analysis session is
/// created. Registration is idempotent: re-running replaces providers with
/// the same engine id rather than duplicating them.
public enum EngineBootstrap {

    public static func installDefaults() async {
        let registry = EngineRegistry.shared
        // llvm-objdump first: its container mode covers stubs sections that
        // `otool -x` does not disassemble. otool remains the fallback for
        // environments without an LLVM toolchain.
        await registry.register(disassembler: ObjDumpDisassembler())
        await registry.register(disassembler: OtoolDisassembler())
        await registry.register(decompiler: GhidraDecompiler())
        await registry.register(decompiler: AngrDecompiler())
    }
}
