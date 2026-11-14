import Foundation


public enum ImportExportAnalysis {
    
    public static func importedFunctions(of image: BinaryImage) -> [BinaryImport] {
        image.imports
    }

    
    public static func exportedFunctions(of image: BinaryImage) -> [BinaryExport] {
        image.exports.sorted { $0.address.value < $1.address.value }
    }

    
    public static func reExports(of image: BinaryImage) -> [BinaryDependency] {
        image.dependencies.filter { $0.kind == "reexport" || $0.kind == "upward" }
    }
}
