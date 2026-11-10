import Foundation

/// Validation for user- and tool-supplied strings before they reach the
/// model, persistence layer or UI. All failures throw
/// `DecompilerError.invalidRequest`.
public enum InputValidation {
    /// Maximum length of a symbol/function name.
    public static let maxSymbolNameLength = 256
    /// Maximum length of a project name.
    public static let maxProjectNameLength = 128

    /// Validate and normalize a symbol or function name.
    /// Rejects empty results, names over 256 characters, and any name
    /// containing control characters (including newlines).
    /// Returns the trimmed name.
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

    /// Validate an address string ("0x1234", hex or decimal) and return
    /// the parsed `DecompilerAddress` (virtual kind by default).
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

    /// Validate a project name: non-empty, bounded length, no path
    /// separators or traversal components (the name becomes a bundle
    /// directory name).
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

    /// Strip control characters and collapse runs of whitespace for safe
    /// display in UI labels, logs and reports.
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

    /// True when the string contains C0/C1 control characters or
    /// bidirectional/format controls that could spoof display.
    public static func containsControlCharacters(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            CharacterSet.controlCharacters.contains(scalar)
                || (scalar.value >= 0x202A && scalar.value <= 0x202E)
                || (scalar.value >= 0x2066 && scalar.value <= 0x2069)
        }
    }
}
