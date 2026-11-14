import Foundation


public enum SymbolAnalysis {
    
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

    
    public static func imports(of image: BinaryImage) -> [BinaryImport] {
        image.imports
    }

    
    public static func exports(of image: BinaryImage) -> [BinaryExport] {
        image.exports.sorted { $0.address.value < $1.address.value }
    }

    
    public static func dependencies(of image: BinaryImage) -> [BinaryDependency] {
        image.dependencies
    }
}
