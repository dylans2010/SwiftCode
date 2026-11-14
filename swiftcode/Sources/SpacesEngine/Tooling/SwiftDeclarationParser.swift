import Foundation

public enum SwiftDeclarationParser {
    public static let parsingNote = "Heuristic line-based declaration parser. It scans declaration keywords and tracks braces to find declaration bodies. It is not a full SwiftSyntax parse, so unusual formatting, braces inside string literals, and multiline constructs may be misread."

    public enum DeclarationKind: String, Codable, Sendable, CaseIterable {
        case function = "func"
        case classType = "class"
        case structType = "struct"
        case enumType = "enum"
        case protocolType = "protocol"
        case variable = "var"
        case constant = "let"
        case typealias = "typealias"
        case initializer = "init"
        case extensionType = "extension"
    }

    public struct SwiftDeclaration: Codable, Equatable, Sendable, Hashable {
        public var kind: DeclarationKind
        public var name: String
        public var signature: String
        public var line: Int
        public var isPublic: Bool
        public var body: String

        public init(kind: DeclarationKind, name: String, signature: String, line: Int, isPublic: Bool, body: String) {
            self.kind = kind
            self.name = name
            self.signature = signature
            self.line = line
            self.isPublic = isPublic
            self.body = body
        }
    }

    public static func parse(_ source: String) -> [SwiftDeclaration] {
        let rawLines = source.components(separatedBy: "\n")
        let lines = rawLines.map { stripLineComment($0) }
        var declarations: [SwiftDeclaration] = []
        var openStack: [(index: Int, depthBefore: Int)] = []
        var depth = 0
        var index = 0
        while index < lines.count {
            let line = lines[index]
            let depthBefore = depth
            if let found = declarationStarting(at: index, lines: lines) {
                var declaration = found.declaration
                declaration.line = index + 1
                declarations.append(declaration)
                let consumed = found.signatureLineCount
                var signatureBraces = 0
                for offset in 0..<consumed {
                    let counts = braceCounts(lines[index + offset])
                    signatureBraces += counts.open - counts.close
                }
                if signatureBraces > 0 {
                    openStack.append((index: declarations.count - 1, depthBefore: depthBefore))
                }
                index += consumed
                for offset in 0..<consumed {
                    let counts = braceCounts(lines[index - consumed + offset])
                    depth += counts.open - counts.close
                }
                closeFinishedDeclarations(lines: lines, endLine: index - 1, depth: depth, declarations: &declarations, openStack: &openStack)
                continue
            }
            let counts = braceCounts(line)
            depth += counts.open - counts.close
            closeFinishedDeclarations(lines: lines, endLine: index, depth: depth, declarations: &declarations, openStack: &openStack)
            index += 1
        }
        for entry in openStack {
            var declaration = declarations[entry.index]
            let start = declaration.line - 1
            declaration.body = rawLines[start..<rawLines.count].joined(separator: "\n")
            declarations[entry.index] = declaration
        }
        return declarations
    }

    private static func closeFinishedDeclarations(lines: [String], endLine: Int, depth: Int, declarations: inout [SwiftDeclaration], openStack: inout [(index: Int, depthBefore: Int)]) {
        while let top = openStack.last, depth <= top.depthBefore {
            openStack.removeLast()
            var declaration = declarations[top.index]
            let start = declaration.line - 1
            let end = min(endLine, lines.count - 1)
            if start <= end {
                declaration.body = lines[start...end].joined(separator: "\n")
            }
            declarations[top.index] = declaration
        }
    }

    private struct FoundDeclaration {
        var declaration: SwiftDeclaration
        var signatureLineCount: Int
    }

    private static func declarationStarting(at index: Int, lines: [String]) -> FoundDeclaration? {
        let raw = lines[index].trimmingCharacters(in: .whitespaces)
        let cleaned = stripLeadingClosers(raw)
        guard !cleaned.isEmpty else { return nil }
        let withoutAttributes = stripLeadingAttributes(cleaned)
        let words = withoutAttributes.components(separatedBy: CharacterSet(charactersIn: " \t({<:=")).filter { !$0.isEmpty }
        guard !words.isEmpty else { return nil }
        let modifiers: Set<String> = ["public", "open", "private", "fileprivate", "internal", "final", "static", "override", "required", "convenience", "lazy", "weak", "unowned", "mutating", "nonmutating", "indirect", "isolated", "nonisolated"]
        var cursor = 0
        var isPublic = false
        while cursor < words.count {
            let word = words[cursor]
            if word == "public" || word == "open" {
                isPublic = true
                cursor += 1
                continue
            }
            if modifiers.contains(word) {
                cursor += 1
                continue
            }
            if word == "class" && cursor + 1 < words.count && (words[cursor + 1] == "func" || words[cursor + 1] == "var" || words[cursor + 1] == "let") {
                cursor += 1
                continue
            }
            break
        }
        guard cursor < words.count else { return nil }
        let keyword = words[cursor]
        let kind: DeclarationKind?
        switch keyword {
        case "func": kind = .function
        case "class": kind = .classType
        case "struct": kind = .structType
        case "enum": kind = .enumType
        case "protocol": kind = .protocolType
        case "var": kind = .variable
        case "let": kind = .constant
        case "typealias": kind = .typealias
        case "init": kind = .initializer
        case "extension": kind = .extensionType
        default: kind = nil
        }
        guard let foundKind = kind else { return nil }
        let keywordRange = withoutAttributes.range(of: keyword, options: [], range: nil, locale: nil)
        guard let range = keywordRange else { return nil }
        let afterKeyword = String(withoutAttributes[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        let name: String
        if foundKind == .initializer {
            name = "init"
        } else {
            name = leadingName(afterKeyword, allowDots: foundKind == .extensionType)
            guard !name.isEmpty else { return nil }
        }
        var signatureLines: [String] = [cleaned]
        var lineCount = 1
        var openParens = cleaned.filter { $0 == "(" }.count - cleaned.filter { $0 == ")" }.count
        while openParens > 0 && index + lineCount < lines.count && lineCount < 12 {
            let next = lines[index + lineCount].trimmingCharacters(in: .whitespaces)
            signatureLines.append(next)
            openParens += next.filter { $0 == "(" }.count - next.filter { $0 == ")" }.count
            lineCount += 1
            if next.contains("{") { break }
        }
        let signature = signatureLines.joined(separator: " ")
        let declaration = SwiftDeclaration(kind: foundKind, name: name, signature: signature, line: index + 1, isPublic: isPublic, body: "")
        return FoundDeclaration(declaration: declaration, signatureLineCount: lineCount)
    }

    private static func leadingName(_ text: String, allowDots: Bool) -> String {
        var result = ""
        for character in text {
            if character.isLetter || character.isNumber || character == "_" || character == "$" || (allowDots && character == ".") {
                result.append(character)
            } else {
                break
            }
        }
        return result
    }

    private static func stripLeadingClosers(_ line: String) -> String {
        var text = line
        while text.hasPrefix("}") {
            text = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        return text
    }

    private static func stripLeadingAttributes(_ line: String) -> String {
        var text = line
        while text.hasPrefix("@") {
            guard let space = text.firstIndex(of: " ") else { return "" }
            if let openParen = text.firstIndex(of: "("), openParen < space {
                var scanDepth = 0
                var closeIndex: String.Index? = nil
                var cursor = openParen
                while cursor < text.endIndex {
                    if text[cursor] == "(" { scanDepth += 1 }
                    if text[cursor] == ")" {
                        scanDepth -= 1
                        if scanDepth == 0 { closeIndex = cursor; break }
                    }
                    cursor = text.index(after: cursor)
                }
                if let close = closeIndex {
                    text = String(text[text.index(after: close)...]).trimmingCharacters(in: .whitespaces)
                    continue
                }
            }
            text = String(text[text.index(after: space)...]).trimmingCharacters(in: .whitespaces)
        }
        return text
    }

    private static func stripLineComment(_ line: String) -> String {
        var inString = false
        var escaped = false
        var cursor = line.startIndex
        while cursor < line.endIndex {
            let character = line[cursor]
            if escaped {
                escaped = false
                cursor = line.index(after: cursor)
                continue
            }
            if character == "\\" && inString {
                escaped = true
                cursor = line.index(after: cursor)
                continue
            }
            if character == "\"" {
                inString.toggle()
                cursor = line.index(after: cursor)
                continue
            }
            if !inString && character == "/" {
                let next = line.index(after: cursor)
                if next < line.endIndex && line[next] == "/" {
                    return String(line[..<cursor])
                }
            }
            cursor = line.index(after: cursor)
        }
        return line
    }

    private static func braceCounts(_ line: String) -> (open: Int, close: Int) {
        var inString = false
        var escaped = false
        var open = 0
        var close = 0
        for character in line {
            if escaped {
                escaped = false
                continue
            }
            if character == "\\" && inString {
                escaped = true
                continue
            }
            if character == "\"" {
                inString.toggle()
                continue
            }
            if inString { continue }
            if character == "{" { open += 1 }
            if character == "}" { close += 1 }
        }
        return (open, close)
    }
}

enum ToolingStorage {
    static func toolingDir(repo: Repository) throws -> URL {
        let dir = repo.metaURL.appendingPathComponent("tooling")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func appendJSONLine<T: Encodable>(repo: Repository, file: String, value: T) throws {
        try repo.withLock {
            let dir = try toolingDir(repo: repo)
            let url = dir.appendingPathComponent(file)
            let data = try JSONEncoder().encode(value)
            var line = data
            line.append(contentsOf: [0x0A])
            if FileManager.default.fileExists(atPath: url.path) {
                let handle = try FileHandle(forWritingTo: url)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: line)
            } else {
                try line.write(to: url, options: .atomic)
            }
        }
    }

    static func readJSONLines<T: Decodable>(repo: Repository, file: String) throws -> [T] {
        let url = try toolingDir(repo: repo).appendingPathComponent(file)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        var records: [T] = []
        let decoder = JSONDecoder()
        for line in text.components(separatedBy: "\n") where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            if let record = try? decoder.decode(T.self, from: Data(line.utf8)) {
                records.append(record)
            }
        }
        return records
    }

    static func atomicWriteJSON<T: Encodable>(repo: Repository, relativePath: String, value: T) throws {
        let url = repo.metaURL.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let data = try encoder.encode(value)
        let tmp = url.deletingLastPathComponent().appendingPathComponent(UUID().uuidString + ".tmp")
        try data.write(to: tmp, options: .atomic)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.moveItem(at: tmp, to: url)
    }

    static func readJSON<T: Decodable>(repo: Repository, relativePath: String) throws -> T? {
        let url = repo.metaURL.appendingPathComponent(relativePath)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try JSONDecoder().decode(T.self, from: data)
    }

    static func flatTree(repo: Repository, rev: String) throws -> [String: (oid: ObjectID, mode: FileMode)] {
        let oid = try repo.resolveRevision(rev)
        let commit = try repo.commitObject(oid)
        return try TreeBuilder.flattenTree(repo: repo, treeOID: commit.tree)
    }

    static func blobText(repo: Repository, rev: String, path: String) throws -> String? {
        let flat = try flatTree(repo: repo, rev: rev)
        guard let entry = flat[path] else { return nil }
        let data = try repo.blobData(entry.oid)
        return String(data: data, encoding: .utf8)
    }

    static func swiftPaths(repo: Repository, rev: String) throws -> [String] {
        let flat = try flatTree(repo: repo, rev: rev)
        return flat.keys.filter { $0.hasSuffix(".swift") }.sorted()
    }
}
