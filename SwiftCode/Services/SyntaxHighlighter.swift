import UIKit

/// Provides syntax-highlighted NSAttributedString for Swift source code.
final class SyntaxHighlighter {
    static let shared = SyntaxHighlighter()
    private init() { buildPatterns() }

    // MARK: - Theme

    struct Theme {
        let background: UIColor
        let defaultText: UIColor
        let keyword: UIColor
        let string: UIColor
        let comment: UIColor
        let number: UIColor
        let type: UIColor
        let function: UIColor
        let attribute: UIColor

        static let dark = Theme(
            background: UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1),
            defaultText: UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1),
            keyword: UIColor(red: 0.98, green: 0.45, blue: 0.45, alpha: 1),
            string: UIColor(red: 0.98, green: 0.70, blue: 0.45, alpha: 1),
            comment: UIColor(red: 0.45, green: 0.72, blue: 0.45, alpha: 1),
            number: UIColor(red: 0.68, green: 0.53, blue: 0.95, alpha: 1),
            type: UIColor(red: 0.55, green: 0.85, blue: 0.98, alpha: 1),
            function: UIColor(red: 0.85, green: 0.85, blue: 0.45, alpha: 1),
            attribute: UIColor(red: 0.80, green: 0.65, blue: 0.40, alpha: 1)
        )
    }

    // MARK: - Highlight

    private var patterns: [(regex: NSRegularExpression, attribute: NSAttributedString.Key, color: (Theme) -> UIColor)] = []
    private let font = UIFont(name: "Menlo", size: 14) ?? UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)

    func highlight(_ source: String, theme: Theme = .dark) -> NSAttributedString {
        let result = NSMutableAttributedString(string: source)
        let range = NSRange(source.startIndex..., in: source)

        // Base attributes
        result.addAttributes([
            .font: font,
            .foregroundColor: theme.defaultText
        ], range: range)

        // Apply each pattern in order
        for pattern in patterns {
            let matches = pattern.regex.matches(in: source, range: range)
            for match in matches {
                let matchRange = match.range(at: match.numberOfRanges > 1 ? 1 : 0)
                guard matchRange.location != NSNotFound else { continue }
                result.addAttribute(pattern.attribute, value: pattern.color(theme), range: matchRange)
            }
        }

        return result
    }

    // MARK: - Pattern Building

    private func buildPatterns() {
        // Comments — must come before other patterns
        addPattern(#"(\/\/[^\n]*)"#, color: \.comment)
        addPattern(#"(\/\*[\s\S]*?\*\/)"#, color: \.comment)

        // String literals (including multi-line)
        addPattern(#"(\"(?:[^\"\\]|\\.)*\")"#, color: \.string)
        addPattern(#"(\"\"\"[\s\S]*?\"\"\")"#, color: \.string)

        // Keywords
        let keywords = [
            "import", "struct", "class", "enum", "protocol", "extension",
            "func", "var", "let", "if", "else", "for", "while", "return",
            "switch", "case", "default", "break", "continue", "guard",
            "in", "is", "as", "try", "catch", "throw", "throws", "rethrows",
            "async", "await", "actor", "init", "deinit", "subscript",
            "get", "set", "willSet", "didSet", "static", "final", "open",
            "public", "private", "internal", "fileprivate", "override",
            "mutating", "nonmutating", "lazy", "weak", "unowned",
            "true", "false", "nil", "self", "super", "typealias",
            "where", "some", "any", "inout", "defer"
        ]
        let keywordsPattern = "\\b(\(keywords.joined(separator: "|")))\\b"
        addPattern(keywordsPattern, color: \.keyword)

        // Types (capitalized identifiers)
        addPattern(#"\b([A-Z][a-zA-Z0-9_]*)\b"#, color: \.type)

        // Function names
        addPattern(#"\bfunc\s+([a-zA-Z_][a-zA-Z0-9_]*)"#, color: \.function, captureGroup: 1)

        // Attributes (@MainActor, @State, etc.)
        addPattern(#"(@[a-zA-Z_][a-zA-Z0-9_]*)"#, color: \.attribute)

        // Numeric literals
        addPattern(#"\b(\d+\.?\d*(?:e[+-]?\d+)?)\b"#, color: \.number)
        addPattern(#"\b(0x[0-9a-fA-F]+)\b"#, color: \.number)
    }

    private func addPattern(_ pattern: String, color: @escaping (Theme) -> UIColor, captureGroup: Int = 0) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return }
        patterns.append((regex: regex, attribute: .foregroundColor, color: color))
    }
}
