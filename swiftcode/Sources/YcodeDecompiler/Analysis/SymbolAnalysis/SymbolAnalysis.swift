import Foundation

/// Symbol database queries over the store's symbol list.
public enum SymbolAnalysis {
    /// Search symbols by substring on name, demangled name, or user name.
    public static func search(_ symbols: [BinarySymbol], query: String,
                              kind: BinarySymbol.Kind? = nil,
                              limit: Int = 100) -> [BinarySymbol] {
        let q = query.lowercased()
        return symbols.filter { s in
            (kind == nil || s.kind == kind) &&
            (s.name.lowercased().contains(q) ||
             (s.demangledName?.lowercased().contains(q) ?? false) ||
             (s.userName?.lowercased().contains(q) ?? false))
        }.prefix(limit).map { $0 }
    }

    /// Imports = undefined symbols + binary imports list merged.
    public static func imports(of image: BinaryImage) -> [BinaryImport] {
        image.imports
    }

    /// Exports sorted by address.
    public static func exports(of image: BinaryImage) -> [BinaryExport] {
        image.exports.sorted { $0.address.value < $1.address.value }
    }

    /// Dependencies grouped by kind.
    public static func dependencies(of image: BinaryImage) -> [BinaryDependency] {
        image.dependencies
    }
}
