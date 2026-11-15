import Foundation

public struct SemanticSearchOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public enum SymbolKind: String, Codable, Sendable, CaseIterable {
        case function, classType = "class", structType = "struct", enumType = "enum",
             protocolType = "protocol", extensionType = "extension",
             variable, typealias, moduleImport = "import"
    }

    public struct Symbol: Codable, Sendable, Hashable {
        public var name: String
        public var kind: SymbolKind
        public var file: String
        public var line: Int
    }

    private struct SymbolIndexFile: Codable {
        var version: Int
        var files: [String: String]
        var symbols: [Symbol]
    }

    public static let matchingNote = "Matching is declaration-aware literal and prefix matching over indexed Swift declarations. There is no machine-learning ranking."

    private var indexURL: URL {
        get throws {
            try SpacesIntelligenceStore.intelligenceDirectory(repo: repo)
                .appendingPathComponent("symbols.json")
        }
    }

    static func declarations(in text: String, file: String) -> [Symbol] {
        let patterns: [(pattern: String, kindFor: (String) -> SymbolKind?)] = [
            ("^\\s*(?:(?:public|private|fileprivate|internal|open|final|override|static|class|lazy|weak|unowned|mutating|nonmutating|convenience|required|indirect|actor)\\s+)*(func|class|struct|enum|protocol|extension)\\s+([A-Za-z_][A-Za-z0-9_]*)",
             { keyword in
                switch keyword {
                case "func": return .function
                case "class": return .classType
                case "struct": return .structType
                case "enum": return .enumType
                case "protocol": return .protocolType
                case "extension": return .extensionType
                default: return nil
                }
             }),
            ("^\\s*(?:(?:public|private|fileprivate|internal|open|final|override|static|class|lazy|weak|unowned)\\s+)*(var|let)\\s+([A-Za-z_][A-Za-z0-9_]*)",
             { _ in .variable }),
            ("^\\s*typealias\\s+([A-Za-z_][A-Za-z0-9_]*)",
             { _ in .typealias }),
            ("^\\s*(?:@testable\\s+)?import\\s+([A-Za-z_][A-Za-z0-9_.]*)",
             { _ in .moduleImport }),
        ]
        var symbols: [Symbol] = []
        let lines = text.components(separatedBy: "\n")
        for (index, line) in lines.enumerated() {
            for entry in patterns {
                guard let regex = try? NSRegularExpression(pattern: entry.pattern) else { continue }
                let range = NSRange(line.startIndex..., in: line)
                guard let match = regex.firstMatch(in: line, options: [], range: range) else { continue }
                let nameRange = match.range(at: match.numberOfRanges - 1)
                guard nameRange.location != NSNotFound,
                      let swiftRange = Range(nameRange, in: line) else { continue }
                let name = String(line[swiftRange])
                let kind: SymbolKind?
                if match.numberOfRanges > 2, let keywordRange = Range(match.range(at: 1), in: line) {
                    kind = entry.kindFor(String(line[keywordRange]))
                } else {
                    kind = entry.kindFor(name)
                }
                guard let resolved = kind else { continue }
                symbols.append(Symbol(name: name, kind: resolved, file: file, line: index + 1))
                break
            }
        }
        return symbols
    }

    static func imports(in text: String) -> [String] {
        var modules: [String] = []
        guard let regex = try? NSRegularExpression(
            pattern: "^\\s*(?:@testable\\s+)?import\\s+([A-Za-z_][A-Za-z0-9_.]*)") else {
            return modules
        }
        for line in text.components(separatedBy: "\n") {
            let range = NSRange(line.startIndex..., in: line)
            if let match = regex.firstMatch(in: line, options: [], range: range),
               let moduleRange = Range(match.range(at: 1), in: line) {
                modules.append(String(line[moduleRange]))
            }
        }
        return modules
    }

    @discardableResult
    public func refreshSymbolIndex() throws -> Int {
        try repo.withLock {
            let url = try indexURL
            let stored: SymbolIndexFile? = try SpacesIntelligenceStore.readJSON(
                SymbolIndexFile.self, from: url)
            let tracked = try repo.index()
            var files: [String: String] = [:]
            var byFile: [String: [Symbol]] = [:]
            if let stored {
                for symbol in stored.symbols {
                    byFile[symbol.file, default: []].append(symbol)
                }
            }
            for path in tracked.entries.keys.sorted() where path.hasSuffix(".swift") {
                guard let entry = tracked.entries[path] else { continue }
                files[path] = entry.oid.hex
                if stored?.files[path] == entry.oid.hex, byFile[path] != nil {
                    continue
                }
                guard let text = SpacesIntelligenceStore.blobText(repo: repo, oid: entry.oid) else {
                    byFile[path] = []
                    continue
                }
                byFile[path] = Self.declarations(in: text, file: path)
            }
            let symbols = byFile.values.flatMap { $0 }
                .sorted { ($0.file, $0.line, $0.name) < ($1.file, $1.line, $1.name) }
            try SpacesIntelligenceStore.writeJSON(
                SymbolIndexFile(version: 1, files: files, symbols: symbols), to: url)
            return symbols.count
        }
    }

    public func symbols() throws -> [Symbol] {
        _ = try refreshSymbolIndex()
        let stored: SymbolIndexFile? = try SpacesIntelligenceStore.readJSON(
            SymbolIndexFile.self, from: indexURL)
        return stored?.symbols ?? []
    }

    public struct RankedSymbol: Sendable {
        public var symbol: Symbol
        public var score: Double
        public var matchedTerms: [String]
        public var method: String

        public init(symbol: Symbol, score: Double, matchedTerms: [String], method: String) {
            self.symbol = symbol
            self.score = score
            self.matchedTerms = matchedTerms
            self.method = method
        }
    }

    public static let rankedMethodDescription = "Token-frequency ranking over the symbol index (symbol names and file paths). This is declaration and symbol matching, not embeddings and not semantic understanding."

    public func rankedSearchSymbols(query: String, kind: SymbolKind? = nil,
                                    limit: Int = 100) throws -> [RankedSymbol] {
        let terms = query.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init).filter { !$0.isEmpty }
        guard !terms.isEmpty else {
            throw SpacesError.invalidArgument("symbol query must not be empty")
        }
        let all = try symbols()
        var ranked: [RankedSymbol] = []
        for symbol in all {
            if let kind, symbol.kind != kind { continue }
            let name = symbol.name.lowercased()
            let nameTokens = name.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
            let fileLower = symbol.file.lowercased()
            let pathTokens = fileLower.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
            var score = 0.0
            var matched: [String] = []
            for term in terms {
                var termScore = 0.0
                if nameTokens.contains(term) {
                    termScore += 3
                } else if nameTokens.contains(where: { $0.hasPrefix(term) }) {
                    termScore += 2
                } else if name.contains(term) {
                    termScore += 1
                }
                if pathTokens.contains(term) {
                    termScore += 1
                } else if fileLower.contains(term) {
                    termScore += 0.5
                }
                if termScore > 0 { matched.append(term) }
                score += termScore
            }
            guard score > 0 else { continue }
            ranked.append(RankedSymbol(symbol: symbol, score: score, matchedTerms: matched,
                                       method: Self.rankedMethodDescription))
        }
        ranked.sort {
            if $0.score != $1.score { return $0.score > $1.score }
            if $0.symbol.name != $1.symbol.name { return $0.symbol.name < $1.symbol.name }
            if $0.symbol.file != $1.symbol.file { return $0.symbol.file < $1.symbol.file }
            return $0.symbol.line < $1.symbol.line
        }
        return Array(ranked.prefix(max(0, limit)))
    }

    public func searchSymbols(query: String, kind: SymbolKind? = nil,
                              limit: Int = 100) throws -> [Symbol] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else {
            throw SpacesError.invalidArgument("symbol query must not be empty")
        }
        let all = try symbols()
        let lowered = needle.lowercased()
        var matches = all.filter { symbol in
            if let kind, symbol.kind != kind { return false }
            let name = symbol.name.lowercased()
            return name.contains(lowered)
        }
        matches.sort {
            let aPrefix = $0.name.lowercased().hasPrefix(lowered)
            let bPrefix = $1.name.lowercased().hasPrefix(lowered)
            if aPrefix != bPrefix { return aPrefix }
            if $0.name != $1.name { return $0.name < $1.name }
            if $0.file != $1.file { return $0.file < $1.file }
            return $0.line < $1.line
        }
        return Array(matches.prefix(max(0, limit)))
    }
}
