import Foundation




public enum InputValidation {
    
    public static let maxSymbolNameLength = 256
    
    public static let maxProjectNameLength = 128

    
    
    
    
    public static func validateSymbolName(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DecompilerError.invalidRequest("symbol name is empty")
        }
        guard trimmed.count <= maxSymbolNameLength else {
            throw DecompilerError.invalidRequest(
                "symbol name exceeds \(maxSymbolNameLength) characters")
        }
        guard !containsControlCharacters(trimmed) else {
            throw DecompilerError.invalidRequest("symbol name contains control characters")
        }
        return trimmed
    }

    
    
    public static func validateAddressString(_ text: String,
                                             defaultKind: DecompilerAddress.Kind = .virtual)
        throws -> DecompilerAddress {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DecompilerError.invalidRequest("address string is empty")
        }
        guard let address = DecompilerAddress.parse(trimmed, defaultKind: defaultKind) else {
            throw DecompilerError.invalidRequest("unparseable address: \(text)")
        }
        return address
    }

    
    
    
    public static func validateProjectName(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DecompilerError.invalidRequest("project name is empty")
        }
        guard trimmed.count <= maxProjectNameLength else {
            throw DecompilerError.invalidRequest(
                "project name exceeds \(maxProjectNameLength) characters")
        }
        guard !trimmed.contains("/") && !trimmed.contains("\\") && !trimmed.contains(":") else {
            throw DecompilerError.invalidRequest("project name contains path separators")
        }
        guard trimmed != "." && trimmed != ".." else {
            throw DecompilerError.invalidRequest("project name is a reserved path component")
        }
        guard !containsControlCharacters(trimmed) else {
            throw DecompilerError.invalidRequest("project name contains control characters")
        }
        return trimmed
    }

    
    
    public static func sanitizeForDisplay(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        var lastWasSpace = false
        for scalar in text.unicodeScalars {
            if CharacterSet.controlCharacters.contains(scalar) {
                if !lastWasSpace { result.unicodeScalars.append(" ") }
                lastWasSpace = true
                continue
            }
            result.unicodeScalars.append(scalar)
            lastWasSpace = scalar == " " || scalar == "\t"
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    
    
    public static func containsControlCharacters(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            CharacterSet.controlCharacters.contains(scalar)
                || (scalar.value >= 0x202A && scalar.value <= 0x202E)
                || (scalar.value >= 0x2066 && scalar.value <= 0x2069)
        }
    }
}
