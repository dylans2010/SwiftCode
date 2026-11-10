import Foundation

/// Dependency analysis views over the parsed image.
public enum DependencyAnalysis {
    /// Libraries this binary links against.
    public static func linkedLibraries(of image: BinaryImage) -> [BinaryDependency] {
        image.dependencies
    }

    /// Imports grouped by providing library.
    public static func importsByLibrary(of image: BinaryImage) -> [String: [BinaryImport]] {
        Dictionary(grouping: image.imports, by: \.library)
    }

    /// Unresolved imports: names present but with no address.
    public static func unresolvedImports(of image: BinaryImage) -> [BinaryImport] {
        image.imports.filter { $0.address == nil }
    }
}
