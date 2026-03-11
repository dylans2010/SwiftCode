import SwiftUI

// MARK: - Syntax Highlighting Engine
// Wraps SyntaxHighlighter and adds multi-theme support.

final class SyntaxHighlightingEngine {
    static let shared = SyntaxHighlightingEngine()
    private init() {}

    // MARK: - Highlight

    func highlight(_ code: String, language: String = "swift", theme: CodeColoringTheme = .dark) -> AttributedString {
        let tokens = tokenize(code, language: language)
        return buildAttributedString(from: tokens, theme: theme)
    }

    // MARK: - Tokenizer

    private enum TokenKind {
        case keyword, string, comment, number, type, function, punctuation, plain
    }

    private struct Token {
        let text: String
        let kind: TokenKind
    }

    private func tokenize(_ code: String, language: String) -> [Token] {
        guard language.lowercased() == "swift" else {
            return [Token(text: code, kind: .plain)]
        }

        var tokens: [Token] = []
        var remaining = code

        let keywordPattern = #"\b(import|class|struct|enum|protocol|extension|func|var|let|if|else|guard|return|switch|case|default|for|while|break|continue|throw|throws|try|catch|do|in|is|as|nil|true|false|self|super|init|deinit|get|set|willSet|didSet|override|final|open|public|internal|private|fileprivate|static|mutating|nonmutating|lazy|weak|unowned|some|any|typealias|associatedtype|where|subscript|operator|infix|prefix|postfix|async|await|actor)\b"#

        let patterns: [(NSRegularExpression, TokenKind)] = [
            (try! NSRegularExpression(pattern: #"//[^\n]*"#), .comment),
            (try! NSRegularExpression(pattern: #"/\*[\s\S]*?\*/"#), .comment),
            (try! NSRegularExpression(pattern: #""(?:[^"\\]|\\.)*""#), .string),
            (try! NSRegularExpression(pattern: keywordPattern), .keyword),
            (try! NSRegularExpression(pattern: #"\b[A-Z][a-zA-Z0-9_]*\b"#), .type),
            (try! NSRegularExpression(pattern: #"\b\d+\.?\d*\b"#), .number),
            (try! NSRegularExpression(pattern: #"\b[a-z_][a-zA-Z0-9_]*\s*(?=\()"#), .function),
        ]

        var processedRanges: [NSRange] = []
        var allMatches: [(NSRange, TokenKind)] = []

        let nsCode = code as NSString
        let fullRange = NSRange(location: 0, length: nsCode.length)

        for (regex, kind) in patterns {
            let matches = regex.matches(in: code, range: fullRange)
            for match in matches {
                let range = match.range
                let overlaps = processedRanges.contains { NSIntersectionRange($0, range).length > 0 }
                if !overlaps {
                    allMatches.append((range, kind))
                    processedRanges.append(range)
                }
            }
        }

        let sorted = allMatches.sorted { $0.0.location < $1.0.location }

        var cursor = 0
        for (range, kind) in sorted {
            if range.location > cursor {
                let plainRange = NSRange(location: cursor, length: range.location - cursor)
                tokens.append(Token(text: nsCode.substring(with: plainRange), kind: .plain))
            }
            tokens.append(Token(text: nsCode.substring(with: range), kind: kind))
            cursor = range.location + range.length
        }
        if cursor < nsCode.length {
            tokens.append(Token(text: nsCode.substring(from: cursor), kind: .plain))
        }

        return tokens
    }

    private func buildAttributedString(from tokens: [Token], theme: CodeColoringTheme) -> AttributedString {
        var result = AttributedString()
        for token in tokens {
            var part = AttributedString(token.text)
            part.foregroundColor = color(for: token.kind, theme: theme)
            if case .keyword = token.kind {
                part.font = .system(size: CGFloat(AppSettings.shared.editorFontSize), design: .monospaced).bold()
            } else {
                part.font = .system(size: CGFloat(AppSettings.shared.editorFontSize), design: .monospaced)
            }
            result.append(part)
        }
        return result
    }

    private func color(for kind: TokenKind, theme: CodeColoringTheme) -> Color {
        switch kind {
        case .keyword:     return theme.keywordColor
        case .string:      return theme.stringColor
        case .comment:     return theme.commentColor
        case .number:      return theme.numberColor
        case .type:        return theme.typeColor
        case .function:    return theme.functionColor
        case .punctuation: return theme.plainColor
        case .plain:       return theme.plainColor
        }
    }
}
