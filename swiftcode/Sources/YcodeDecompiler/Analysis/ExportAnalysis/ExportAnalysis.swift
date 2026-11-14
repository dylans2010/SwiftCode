import Foundation


public enum ExportAnalysis {
    
    public static func exports(of image: BinaryImage) -> [BinaryExport] {
        image.exports.sorted { $0.address.value < $1.address.value }
    }

    
    public static func hasExports(of image: BinaryImage) -> Bool { !image.exports.isEmpty }
}
