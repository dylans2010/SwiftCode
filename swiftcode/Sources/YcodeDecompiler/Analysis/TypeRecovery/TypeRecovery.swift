import Foundation





public enum TypeRecovery {
    
    
    
    public static func recover(image: BinaryImage) -> [TypeInfo] {
        var out: [TypeInfo] = []
        let provenance = AnalysisSource(provenance: .formatParser, pass: "type-recovery")

        
        
        if image.hasDebugInfo {
            
            
        }
        _ = provenance
        _ = out
        return out
    }
}
