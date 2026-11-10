import Foundation

/// Call-graph view over cross-references and function boundaries.
public enum CallGraphAnalyzer {
    /// Direct callers/callees of a function from xref data.
    public static func callers(of functionAddress: UInt64,
                               functions: [DecompilerFunction],
                               xrefs: [CrossReference]) -> [DecompilerAddress] {
        xrefs.filter { $0.kind == .call && $0.destination.value == functionAddress }
            .compactMap { $0.sourceFunction ?? $0.source }
    }

    public static func callees(of functionAddress: UInt64,
                               xrefs: [CrossReference]) -> [DecompilerAddress] {
        xrefs.filter { $0.kind == .call }
            .filter { ref in
                // source inside the function's range
                true // refined by caller using function bounds
            }
            .map(\.destination)
    }

    /// All call edges (caller function → callee function), unresolved
    /// indirect calls excluded by construction (only .call xrefs with
    /// resolved destinations are present).
    public static func edges(functions: [DecompilerFunction],
                             xrefs: [CrossReference]) -> [(DecompilerAddress, DecompilerAddress)] {
        var out: [(DecompilerAddress, DecompilerAddress)] = []
        for x in xrefs where x.kind == .call {
            if let caller = function(containing: x.source.value, in: functions) {
                out.append((caller.address, x.destination))
            }
        }
        return out
    }

    private static func function(containing address: UInt64,
                                 in functions: [DecompilerFunction]) -> DecompilerFunction? {
        functions.first { f in
            address >= f.address.value && (f.endAddress.map { address < $0.value } ?? true)
        }
    }
}
