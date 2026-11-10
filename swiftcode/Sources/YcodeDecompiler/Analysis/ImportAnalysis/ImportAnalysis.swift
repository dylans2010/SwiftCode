import Foundation

/// Import/export analysis helpers.
public enum ImportExportAnalysis {
    /// Imported functions with library attribution.
    public static func importedFunctions(of image: BinaryImage) -> [BinaryImport] {
        image.imports
    }

    /// Exported symbols sorted by address.
    public static func exportedFunctions(of image: BinaryImage) -> [BinaryExport] {
        image.exports.sorted { $0.address.value < $1.address.value }
    }

    /// Re-exports (kind == reexport dependencies).
    public static func reExports(of image: BinaryImage) -> [BinaryDependency] {
        image.dependencies.filter { $0.kind == "reexport" || $0.kind == "upward" }
    }
}
