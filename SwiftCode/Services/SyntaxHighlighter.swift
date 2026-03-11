import UIKit

/// Provides syntax-highlighted NSAttributedString for source files.
/// Supports Swift, shell scripts (.sh), JSON, property lists (.plist), and Markdown (.md).
final class SyntaxHighlighter {
    static let shared = SyntaxHighlighter()
    private init() { buildAllPatterns() }

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

    // MARK: - Pattern Storage

    private typealias PatternEntry = (regex: NSRegularExpression,
                                      captureGroup: Int,
                                      color: (Theme) -> UIColor)

    private var swiftPatterns: [PatternEntry] = []
    private var shellPatterns: [PatternEntry] = []
    private var jsonPatterns: [PatternEntry] = []
    private var plistPatterns: [PatternEntry] = []
    private var markdownPatterns: [PatternEntry] = []

    // MARK: - Highlight (entry point)

    /// Highlights `source` using rules for the given file extension.
    func highlight(_ source: String, fileExtension: String = "swift", theme: Theme = .dark) -> NSAttributedString {
        let patterns = patternsForExtension(fileExtension)
        return apply(patterns: patterns, to: source, theme: theme)
    }

    // MARK: - Apply Patterns

    private func apply(patterns: [PatternEntry], to source: String, theme: Theme) -> NSAttributedString {
        let font = TextLayoutEngine.editorFont()
        let paragraphStyle = TextLayoutEngine.paragraphStyle()
        let result = NSMutableAttributedString(string: source)
        let range = NSRange(source.startIndex..., in: source)

        result.addAttributes([
            .font: font,
            .foregroundColor: theme.defaultText,
            .paragraphStyle: paragraphStyle
        ], range: range)

        for entry in patterns {
            let matches = entry.regex.matches(in: source, range: range)
            for match in matches {
                let idx = match.numberOfRanges > entry.captureGroup ? entry.captureGroup : 0
                let matchRange = match.range(at: idx)
                guard matchRange.location != NSNotFound else { continue }
                result.addAttribute(.foregroundColor, value: entry.color(theme), range: matchRange)
            }
        }
        return result
    }

    // MARK: - Language Selection

    private func patternsForExtension(_ ext: String) -> [PatternEntry] {
        switch ext.lowercased() {
        case "sh", "bash", "zsh": return shellPatterns
        case "json": return jsonPatterns
        case "plist": return plistPatterns
        case "md", "markdown": return markdownPatterns
        default: return swiftPatterns
        }
    }

    // MARK: - Pattern Building

    private func buildAllPatterns() {
        buildSwiftPatterns()
        buildShellPatterns()
        buildJSONPatterns()
        buildPlistPatterns()
        buildMarkdownPatterns()
    }

    // MARK: Swift

    private func buildSwiftPatterns() {
        var p: [PatternEntry] = []
        add(#"(\/\/[^\n]*)"#, color: \.comment, to: &p)
        add(#"(\/\*[\s\S]*?\*\/)"#, color: \.comment, to: &p)
        add(#"(\"\"\"[\s\S]*?\"\"\")"#, color: \.string, to: &p)
        add(#"(\"(?:[^\"\\]|\\.)*\")"#, color: \.string, to: &p)

        let kw = ["import","struct","class","enum","protocol","extension",
                  "func","var","let","if","else","for","while","return",
                  "switch","case","default","break","continue","guard",
                  "in","is","as","try","catch","throw","throws","rethrows",
                  "async","await","actor","init","deinit","subscript",
                  "get","set","willSet","didSet","static","final","open",
                  "public","private","internal","fileprivate","override",
                  "mutating","nonmutating","lazy","weak","unowned",
                  "true","false","nil","self","super","typealias",
                  "where","some","any","inout","defer"]
        add("\\b(\(kw.joined(separator: "|")))\\b", color: \.keyword, to: &p)
        add(#"\b([A-Z][a-zA-Z0-9_]*)\b"#, color: \.type, to: &p)
        add(#"\bfunc\s+([a-zA-Z_][a-zA-Z0-9_]*)"#, color: \.function, captureGroup: 1, to: &p)
        add(#"(@[a-zA-Z_][a-zA-Z0-9_]*)"#, color: \.attribute, to: &p)
        add(#"\b(\d+\.?\d*(?:e[+-]?\d+)?)\b"#, color: \.number, to: &p)
        add(#"\b(0x[0-9a-fA-F]+)\b"#, color: \.number, to: &p)
        swiftPatterns = p
    }

    // MARK: Shell

    private func buildShellPatterns() {
        var p: [PatternEntry] = []
        add(#"(#[^\n]*)"#, color: \.comment, to: &p)
        add(#"(\"(?:[^\"\\]|\\.)*\")"#, color: \.string, to: &p)
        add(#"('(?:[^'\\]|\\.)*')"#, color: \.string, to: &p)
        let kw = ["if","then","else","elif","fi","for","while","do",
                  "done","case","esac","in","function","return","exit",
                  "local","export","source","true","false","echo","read"]
        add("\\b(\(kw.joined(separator: "|")))\\b", color: \.keyword, to: &p)
        let cmds = ["mkdir","cp","rm","cd","ls","cat","grep","sed","awk",
                    "chmod","chown","curl","wget","git","brew","swift","xcodebuild"]
        add("\\b(\(cmds.joined(separator: "|")))\\b", color: \.function, to: &p)
        add(#"(\$\{?[A-Za-z_][A-Za-z0-9_]*\}?)"#, color: \.attribute, to: &p)
        add(#"\b(\d+)\b"#, color: \.number, to: &p)
        shellPatterns = p
    }

    // MARK: JSON

    private func buildJSONPatterns() {
        var p: [PatternEntry] = []
        add(#"(\"(?:[^\"\\]|\\.)*\")"#, color: \.string, to: &p)
        add(#"\b(true|false|null)\b"#, color: \.keyword, to: &p)
        add(#"(-?\d+\.?\d*(?:[eE][+-]?\d+)?)"#, color: \.number, to: &p)
        jsonPatterns = p
    }

    // MARK: Plist

    private func buildPlistPatterns() {
        var p: [PatternEntry] = []
        add(#"(<!--[\s\S]*?-->)"#, color: \.comment, to: &p)
        add(#"(<[^>]+>)"#, color: \.keyword, to: &p)
        add(#">([^<]+)<"#, color: \.string, captureGroup: 1, to: &p)
        plistPatterns = p
    }

    // MARK: Markdown

    private func buildMarkdownPatterns() {
        var p: [PatternEntry] = []
        add(#"(^#{1,6}\s+[^\n]+)"#, color: \.keyword, to: &p, options: [.anchorsMatchLines])
        add(#"(\*\*[^\*]+\*\*|__[^_]+__)"#, color: \.type, to: &p)
        add(#"(\*[^\*\n]+\*|_[^_\n]+_)"#, color: \.function, to: &p)
        add(#"(`[^`\n]+`)"#, color: \.string, to: &p)
        add(#"(```[\s\S]*?```)"#, color: \.string, to: &p)
        add(#"(\[[^\]]+\]\([^\)]+\))"#, color: \.attribute, to: &p)
        add(#"(^>\s+[^\n]*)"#, color: \.comment, to: &p, options: [.anchorsMatchLines])
        markdownPatterns = p
    }

    // MARK: - Helper

    private func add(
        _ pattern: String,
        color: @escaping (Theme) -> UIColor,
        captureGroup: Int = 0,
        to list: inout [PatternEntry],
        options: NSRegularExpression.Options = [.dotMatchesLineSeparators]
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
        list.append((regex: regex, captureGroup: captureGroup, color: color))
    }
}
