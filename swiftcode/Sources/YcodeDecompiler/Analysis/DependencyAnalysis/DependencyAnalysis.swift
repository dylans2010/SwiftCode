import Foundation


public enum DependencyAnalysis {
    
    public static func linkedLibraries(of image: BinaryImage) -> [BinaryDependency] {
        image.dependencies
    }

    
    public static func importsByLibrary(of image: BinaryImage) -> [String: [BinaryImport]] {
        Dictionary(grouping: image.imports, by: \.library)
    }

    
    public static func unresolvedImports(of image: BinaryImage) -> [BinaryImport] {
        image.imports.filter { $0.address == nil }
    }
}
