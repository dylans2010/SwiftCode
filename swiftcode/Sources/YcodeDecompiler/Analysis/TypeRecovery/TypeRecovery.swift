import Foundation

/// Type recovery: today this surfaces types that the format itself declares
/// (e.g. nothing for stripped Mach-O) plus user-defined types loaded from the
/// project store. Backend-provided types arrive via DecompilerProvider results
/// and are merged by the session.
public enum TypeRecovery {
    /// Recover types declared by the binary format itself.
    /// Mach-O/ELF/PE carry no rich type info without DWARF/PDB — in that case
    /// we return an empty set rather than fabricate types.
    public static func recover(image: BinaryImage) -> [TypeInfo] {
        var out: [TypeInfo] = []
        let provenance = AnalysisSource(provenance: .formatParser, pass: "type-recovery")

        // Function signature types are represented as function types so the
        // type browser is never empty when functions exist.
        if image.hasDebugInfo {
            // DWARF/PDB parsing is delegated to the decompiler backend; we do
            // not claim recovery we did not perform.
        }
        _ = provenance
        _ = out
        return out
    }
}
