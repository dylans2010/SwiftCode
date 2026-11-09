import YcodeIDECore
import Foundation

public struct CodeSymbol: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var kind: SymbolKind
    public var lineNumber: Int
    public var isPrivate: Bool

    public init(id: UUID = UUID(), name: String, kind: SymbolKind, lineNumber: Int, isPrivate: Bool) {
        self.id = id
        self.name = name
        self.kind = kind
        self.lineNumber = lineNumber
        self.isPrivate = isPrivate
    }

    public enum SymbolKind: String, CaseIterable, Sendable {
        case `class`      = "class"
        case `struct`     = "struct"
        case `enum`       = "enum"
        case `protocol`   = "protocol"
        case `extension`  = "extension"
        case function     = "func"
        case variable     = "var"
        case constant     = "let"
        case typeAlias    = "typealias"

        public var icon: String {
            switch self {
            case .class:      return "cube.fill"
            case .struct:     return "square.fill"
            case .enum:       return "list.bullet"
            case .protocol:   return "checkmark.seal.fill"
            case .extension:  return "arrow.up.right.square"
            case .function:   return "function"
            case .variable:   return "v.square"
            case .constant:   return "c.square"
            case .typeAlias:  return "t.square"
            }
        }
    }
}

@MainActor
public final class CodeStructureAnalyzer {
    public static let shared = CodeStructureAnalyzer()
    public init() {}

    public func analyze(_ code: String) -> [CodeSymbol] {
        var symbols: [CodeSymbol] = []
        let lines = code.components(separatedBy: "\n")

        let patterns: [(NSRegularExpression, CodeSymbol.SymbolKind)] = buildPatterns()

        for (lineIndex, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let isPrivate = trimmed.hasPrefix("private ") || trimmed.hasPrefix("fileprivate ")

            for (regex, kind) in patterns {
                let range = NSRange(trimmed.startIndex..., in: trimmed)
                if let match = regex.firstMatch(in: trimmed, range: range),
                   match.numberOfRanges > 1,
                   let nameRange = Range(match.range(at: 1), in: trimmed) {
                    let name = String(trimmed[nameRange])
                    let symbol = CodeSymbol(
                        name: name,
                        kind: kind,
                        lineNumber: lineIndex + 1,
                        isPrivate: isPrivate
                    )
                    symbols.append(symbol)
                    break
                }
            }
        }

        return symbols
    }

    private func buildPatterns() -> [(NSRegularExpression, CodeSymbol.SymbolKind)] {
        let defs: [(String, CodeSymbol.SymbolKind)] = [
            (#"(?:^|[\s]+)class\s+([A-Za-z_][A-Za-z0-9_]*)[\s<:{]"#,    .class),
            (#"(?:^|[\s]+)struct\s+([A-Za-z_][A-Za-z0-9_]*)[\s<:{]"#,   .struct),
            (#"(?:^|[\s]+)enum\s+([A-Za-z_][A-Za-z0-9_]*)[\s<:{]"#,     .enum),
            (#"(?:^|[\s]+)protocol\s+([A-Za-z_][A-Za-z0-9_]*)[\s<:{]"#, .protocol),
            (#"(?:^|[\s]+)extension\s+([A-Za-z_][A-Za-z0-9_]*)[\s<:{]"#, .extension),
            (#"(?:^|[\s]+)func\s+([A-Za-z_][A-Za-z0-9_]*)\s*[<(]"#,     .function),
            (#"(?:^|[\s]+)var\s+([A-Za-z_][A-Za-z0-9_]*)\s*[:{]"#,      .variable),
            (#"(?:^|[\s]+)let\s+([A-Za-z_][A-Za-z0-9_]*)\s*[:{=]"#,     .constant),
            (#"(?:^|[\s]+)typealias\s+([A-Za-z_][A-Za-z0-9_]*)\s*="#,   .typeAlias),
        ]
        return defs.compactMap { pattern, kind in
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
            return (regex, kind)
        }
    }

    public func statistics(for code: String) -> CodeStatistics {
        let lines = code.components(separatedBy: "\n")
        let nonEmpty = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let commentLines = lines.filter {
            let t = $0.trimmingCharacters(in: .whitespaces)
            return t.hasPrefix("//") || t.hasPrefix("*") || t.hasPrefix("/*")
        }
        let symbols = analyze(code)

        return CodeStatistics(
            totalLines: lines.count,
            nonEmptyLines: nonEmpty.count,
            commentLines: commentLines.count,
            classCount: symbols.filter { $0.kind == .class }.count,
            structCount: symbols.filter { $0.kind == .struct }.count,
            functionCount: symbols.filter { $0.kind == .function }.count,
            variableCount: symbols.filter { $0.kind == .variable || $0.kind == .constant }.count
        )
    }
}

public struct CodeStatistics: Sendable {
    public var totalLines: Int
    public var nonEmptyLines: Int
    public var commentLines: Int
    public var classCount: Int
    public var structCount: Int
    public var functionCount: Int
    public var variableCount: Int

    public var complexityScore: Int {
        return functionCount * 2 + classCount + structCount
    }

    public init(
        totalLines: Int,
        nonEmptyLines: Int,
        commentLines: Int,
        classCount: Int,
        structCount: Int,
        functionCount: Int,
        variableCount: Int
    ) {
        self.totalLines = totalLines
        self.nonEmptyLines = nonEmptyLines
        self.commentLines = commentLines
        self.classCount = classCount
        self.structCount = structCount
        self.functionCount = functionCount
        self.variableCount = variableCount
    }
}
