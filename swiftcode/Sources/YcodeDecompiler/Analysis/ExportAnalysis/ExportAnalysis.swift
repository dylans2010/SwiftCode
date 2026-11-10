import Foundation

/// Export-side analysis: what this binary provides to others.
public enum ExportAnalysis {
    /// All exports with addresses, sorted.
    public static func exports(of image: BinaryImage) -> [BinaryExport] {
        image.exports.sorted { $0.address.value < $1.address.value }
    }

    /// Whether the binary exports any symbols at all.
    public static func hasExports(of image: BinaryImage) -> Bool { !image.exports.isEmpty }
}
