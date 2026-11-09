import Foundation
import YcodeIDECore

private struct IndexedDoc {
    let id: String
    let termFreqs: [String: Int]
    let length: Int
}

private struct ProjectDecl {
    let name: String
    let kind: String
    let signature: String
    let docComment: String
    let filePath: String
    let line: Int
    var tokens: [String: Int] = [:]
}

private struct ContentHit {
    let filePath: String
    let line: Int
    let text: String
    var score: Double = 0
}

@MainActor
public final class LocalDictionaryEngine {
    public static let shared = LocalDictionaryEngine()

    private var docSymbols: [DocSymbol] = []
    private var docSymbolsLoaded = false
    private var docDocs: [IndexedDoc] = []
    private var symbolByName: [String: DocSymbol] = [:]

    private var projectDecls: [ProjectDecl] = []
    private var declDocs: [IndexedDoc] = []
    private var projectIndexKey: String?
    private var projectIndexDate = Date.distantPast

    private var contentDocs: [IndexedDoc] = []
    private var contentFilePaths: [String] = []

    private init() {}

    public func answer(query: String) async -> CodingDictionaryResult? {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return nil }
        let terms = Self.queryTerms(q)
        guard !terms.isEmpty else { return nil }

        await ensureDocCorpus()
        ensureProjectIndex()
        rebuildIDF()

        var candidates: [(score: Double, decl: ProjectDecl)] = []
        var bestDocSymbol: (score: Double, symbol: DocSymbol)? = nil

        for (i, doc) in declDocs.enumerated() {
            let score = bm25(doc, terms: terms)
            if score > 0 { candidates.append((score, projectDecls[i])) }
        }
        for (i, doc) in docDocs.enumerated() {
            let score = bm25(doc, terms: terms)
            if let cur = bestDocSymbol {
                if score > cur.score { bestDocSymbol = (score, docSymbols[i]) }
            } else if score > 0 {
                bestDocSymbol = (score, docSymbols[i])
            }
        }

        candidates.sort { $0.score > $1.score }
        let declScore = candidates.first?.score ?? 0
        let docScore = bestDocSymbol?.score ?? 0

        if declScore > 0 && declScore >= docScore * 0.75 {
            return composeProjectResult(query: q, decl: candidates[0].decl, runnersUp: candidates.dropFirst(4).map(\.decl))
        }
        if let best = bestDocSymbol, docScore > 0 {
            return composeDocSymbolResult(query: q, symbol: best.symbol, score: docScore,
                                          runnersUp: candidates.prefix(4).map(\.decl))
        }
        return composeContentResult(query: q, terms: terms)
    }

    private func ensureDocCorpus() async {
        guard !docSymbolsLoaded else { return }
        docSymbolsLoaded = true
        if let symbols = try? await DocSymbolsLoader.loadSymbols(), !symbols.isEmpty {
            docSymbols = symbols
            var byName: [String: DocSymbol] = [:]
            var docs: [IndexedDoc] = []
            docs.reserveCapacity(symbols.count)
            for sym in symbols {
                byName[sym.name.lowercased()] = sym
                var tf: [String: Int] = [:]
                for t in Self.terms(of: "\(sym.name) \(sym.name) \(sym.name) \(sym.kind) \(sym.framework) \(sym.summary) \(sym.syntax)") {
                    tf[t, default: 0] += 1
                }
                docs.append(IndexedDoc(id: "doc:\(sym.name)", termFreqs: tf, length: tf.values.reduce(0, +)))
            }
            symbolByName = byName
            docDocs = docs
        }
    }

    private func ensureProjectIndex() {
        guard let root = ProjectSessionStore.shared.activeProject?.directoryURL else { return }
        let key = root.path
        if projectIndexKey == key, Date().timeIntervalSince(projectIndexDate) < 120 { return }
        projectIndexKey = key
        projectIndexDate = Date()

        var decls: [ProjectDecl] = []
        var docs: [IndexedDoc] = []
        var cDocs: [IndexedDoc] = []
        var cPaths: [String] = []

        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
                                             options: [.skipsHiddenFiles]) else { return }
        let skipDirs: Set<String> = [".build", ".git", ".swiftpm", "DerivedData", "node_modules", "Carthage", "Pods", ".idea", ".vscode"]
        let codeExts: Set<String> = ["swift", "m", "mm", "h", "c", "cpp", "hpp", "js", "ts", "jsx", "tsx", "py", "rb", "go", "rs", "java", "kt", "sh", "md", "yaml", "yml", "json", "toml"]
        var fileCount = 0
        var contentTokenTotal = 0

        for case let url as URL in enumerator {
            let name = url.lastPathComponent
            if url.pathComponents.contains(where: { skipDirs.contains($0) }) { continue }
            let ext = url.pathExtension.lowercased()
            guard codeExts.contains(ext) else { continue }
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true, (values.fileSize ?? 0) < 1_000_000 else { continue }
            fileCount += 1
            if fileCount > 4000 { break }

            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let rel = url.path.replacingOccurrences(of: root.path + "/", with: "")
            let lines = text.components(separatedBy: .newlines)

            var contentTF: [String: Int] = [:]
            var contentLen = 0
            for line in lines {
                for t in Self.terms(of: line) {
                    contentTF[t, default: 0] += 1
                    contentLen += 1
                    if contentLen > 200_000 { break }
                }
                if contentLen > 200_000 { break }
            }
            if !contentTF.isEmpty {
                cDocs.append(IndexedDoc(id: "file:\(rel)", termFreqs: contentTF, length: contentLen))
                cPaths.append(rel)
                contentTokenTotal += contentLen
            }

            for (idx, line) in lines.enumerated() {
                guard let decl = Self.parseDeclaration(line: line, lines: lines, lineIndex: idx,
                                                       filePath: rel) else { continue }
                var tf: [String: Int] = [:]
                let corpus = "\(decl.name) \(decl.name) \(decl.name) \(decl.kind) \(decl.signature) \(decl.docComment) \(url.deletingPathExtension().lastPathComponent)"
                for t in Self.terms(of: corpus) { tf[t, default: 0] += 1 }
                let length = tf.values.reduce(0, +)
                decls.append(decl)
                docs.append(IndexedDoc(id: "decl:\(rel):\(idx + 1)", termFreqs: tf, length: length))
            }
        }

        projectDecls = decls
        declDocs = docs
        contentDocs = cDocs
        contentFilePaths = cPaths
        _ = contentTokenTotal
    }

    private static let declRegex = try? NSRegularExpression(
        pattern: #"\b(class|struct|enum|protocol|actor|func|var|let|init|deinit|typealias|subscript|extension|import)\s+([A-Za-z_][A-Za-z0-9_]*)"#)

    private static func parseDeclaration(line: String, lines: [String], lineIndex: Int,
                                         filePath: String) -> ProjectDecl? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.hasPrefix("//"), !trimmed.hasPrefix("*"), trimmed.count > 3 else { return nil }
        guard let regex = declRegex else { return nil }
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        guard let match = regex.firstMatch(in: trimmed, range: range), match.numberOfRanges >= 3,
              let kindRange = Range(match.range(at: 1), in: trimmed),
              let nameRange = Range(match.range(at: 2), in: trimmed) else { return nil }
        let kindRaw = String(trimmed[kindRange]).lowercased()
        let name = String(trimmed[nameRange])
        guard name.count > 1 || name == "x" else { return nil }

        var signature = trimmed
        var end = lineIndex
        var braceDelta = 0
        var seenBrace = false
        while end < min(lineIndex + 6, lines.count) {
            let l = lines[end]
            braceDelta += l.filter { $0 == "{" }.count - l.filter { $0 == "}" }.count
            if l.contains("{") { seenBrace = true }
            if seenBrace && braceDelta <= 0 { break }
            if !seenBrace && end > lineIndex && (l.contains("{") || l.trimmingCharacters(in: .whitespaces).isEmpty == false && l.hasSuffix("}")) { break }
            if end > lineIndex { signature += " " + l.trimmingCharacters(in: .whitespaces) }
            end += 1
            if seenBrace && braceDelta > 0 && end - lineIndex > 5 { break }
        }
        if signature.count > 400 { signature = String(signature.prefix(400)) }

        var docLines: [String] = []
        var i = lineIndex - 1
        while i >= 0 {
            let l = lines[i].trimmingCharacters(in: .whitespaces)
            if l.hasPrefix("///") {
                docLines.insert(String(l.dropFirst(3)).trimmingCharacters(in: .whitespaces), at: 0)
                i -= 1
            } else if l.hasPrefix("/**") || l.hasPrefix("*") || l.isEmpty {
                if l.hasPrefix("*/") || l == "*/" { i -= 1; continue }
                if l.hasPrefix("*") {
                    docLines.insert(String(l.dropFirst()).trimmingCharacters(in: .whitespaces), at: 0)
                    i -= 1
                    continue
                }
                if l.isEmpty { i -= 1; continue }
                break
            } else { break }
        }
        let doc = docLines.joined(separator: " ")

        let kindMap: [String: String] = [
            "class": "Class", "struct": "Struct", "enum": "Enum", "protocol": "Protocol",
            "actor": "Actor", "func": "Function", "var": "Property", "let": "Constant",
            "init": "Initializer", "deinit": "Deinitializer", "typealias": "Type Alias",
            "subscript": "Subscript", "extension": "Extension", "import": "Import"
        ]
        return ProjectDecl(name: name, kind: kindMap[kindRaw] ?? kindRaw.capitalized,
                           signature: signature, docComment: doc,
                           filePath: filePath, line: lineIndex + 1)
    }

    private func bm25(_ doc: IndexedDoc, terms: [String]) -> Double {
        let k1 = 1.2, b = 0.75
        var score = 0.0
        let avgLen = max(1.0, Double(allDocsCount == 0 ? 1 : avgDocLength))
        for t in terms {
            let tf = Double(doc.termFreqs[t] ?? 0)
            guard tf > 0 else { continue }
            let df = documentFrequency[t] ?? 0
            let idf = log(1.0 + (Double(totalDocs - df) + 0.5) / (Double(df) + 0.5))
            let denom = tf + k1 * (1 - b + b * Double(doc.length) / avgLen)
            score += idf * (tf * (k1 + 1)) / denom
        }
        return score
    }

    private var allDocsCount = 0
    private var avgDocLength = 0
    private var totalDocs = 0
    private var documentFrequency: [String: Int] = [:]

    private func rebuildIDF() {
        var df: [String: Int] = [:]
        var total = 0
        var lenSum = 0
        for doc in declDocs + docDocs + contentDocs {
            total += 1
            lenSum += doc.length
            for t in doc.termFreqs.keys { df[t, default: 0] += 1 }
        }
        totalDocs = total
        avgDocLength = total > 0 ? lenSum / total : 1
        allDocsCount = total
        documentFrequency = df
    }

    private func composeProjectResult(query: String, decl: ProjectDecl,
                                      runnersUp: [ProjectDecl]) -> CodingDictionaryResult {
        let ref = "\(decl.filePath):\(decl.line)"
        var related: [String] = []
        var notes: [String] = []
        for other in runnersUp where other.name != decl.name {
            related.append(other.name)
            notes.append("\(other.name) — \(other.filePath):\(other.line)")
        }
        let subtitle = decl.docComment.isEmpty
            ? decl.signature
            : String(decl.docComment.prefix { $0 != "." }.prefix(140))
        return CodingDictionaryResult(
            confidence: 92,
            query: query,
            title: decl.name,
            subtitle: subtitle,
            kind: decl.kind,
            category: "Project",
            difficulty: "",
            overview: decl.docComment.isEmpty
                ? "Declared in \(ref)."
                : decl.docComment,
            definition: decl.signature,
            summary: decl.docComment.isEmpty ? decl.signature : decl.docComment,
            syntax: decl.signature,
            parameters: Self.parseParameters(from: decl.signature),
            returnValue: Self.parseReturnValue(from: decl.signature),
            examples: [DictionaryExample(title: decl.filePath, code: decl.signature)],
            bestPractices: [],
            notes: ["Declared at \(ref).", "Matched locally in the open project — no AI was used."] + notes,
            seeAlso: related,
            references: [ref],
            appleDocsSummary: "",
            swiftVersion: "",
            alternativeAPIs: [],
            codeSnippet: decl.signature,
            complexity: "",
            memoryConsiderations: ""
        )
    }

    private func composeDocSymbolResult(query: String, symbol: DocSymbol, score: Double,
                                        runnersUp: [ProjectDecl]) -> CodingDictionaryResult {
        let summary = symbol.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstSentence = summary.split(separator: ".").first.map(String.init) ?? summary
        var related = symbol.seeAlso
        if let inherits = symbol.inheritsFrom, !inherits.isEmpty { related.append(inherits) }
        related.append(contentsOf: symbol.conformsTo)
        for decl in runnersUp.prefix(3) where !related.contains(decl.name) {
            related.append(decl.name)
        }
        var availabilityList: [String] = []
        for (_, v) in symbol.platforms.sorted(by: { $0.key < $1.key }) where !v.isEmpty {
            availabilityList.append(v)
        }
        if !symbol.availability.isEmpty, !availabilityList.contains(symbol.availability) {
            availabilityList.append(symbol.availability)
        }
        var examples: [DictionaryExample] = []
        let sample = symbol.codeSample.trimmingCharacters(in: .whitespacesAndNewlines)
        if !sample.isEmpty {
            examples.append(DictionaryExample(title: "\(symbol.name) — Apple documentation", code: sample))
        }
        let conf = min(97, max(45, Int(score * 12) + 40))
        return CodingDictionaryResult(
            confidence: conf,
            query: query,
            title: symbol.name,
            subtitle: firstSentence,
            kind: symbol.kind.isEmpty ? "Symbol" : symbol.kind,
            category: symbol.framework.isEmpty ? "Documentation" : symbol.framework,
            difficulty: "",
            overview: summary,
            definition: summary,
            summary: firstSentence,
            syntax: symbol.syntax,
            parameters: Self.parseParameters(from: symbol.syntax),
            returnValue: Self.parseReturnValue(from: symbol.syntax),
            examples: examples,
            bestPractices: [],
            notes: ["Matched against the bundled Apple documentation index."],
            seeAlso: related,
            references: [symbol.docPath].filter { !$0.isEmpty },
            appleDocsSummary: summary,
            swiftVersion: "",
            alternativeAPIs: [],
            codeSnippet: sample,
            complexity: "",
            memoryConsiderations: ""
        )
    }

    private func composeContentResult(query: String, terms: [String]) -> CodingDictionaryResult? {
        var hits: [ContentHit] = []
        let querySet = Set(terms)
        for (i, doc) in contentDocs.enumerated() {
            var score = 0.0
            for t in querySet {
                let tf = Double(doc.termFreqs[t] ?? 0)
                guard tf > 0 else { continue }
                let df = documentFrequency[t] ?? 0
                let idf = log(1.0 + (Double(totalDocs - df) + 0.5) / (Double(df) + 0.5))
                score += idf * tf
            }
            if score > 0 { hits.append(ContentHit(filePath: contentFilePaths[i], line: 0, text: "", score: score)) }
        }
        guard !hits.isEmpty else { return nil }
        hits.sort { $0.score > $1.score }
        let top = Array(hits.prefix(5))

        var refs: [String] = []
        var snippets: [DictionaryExample] = []
        for hit in top {
            refs.append(hit.filePath)
            if let excerpt = Self.excerpt(from: hit.filePath, terms: querySet) {
                snippets.append(DictionaryExample(title: hit.filePath, code: excerpt))
            }
        }
        let overview = "No exact symbol or documentation entry matched \"\(query)\", but \(top.count) project file(s) contain relevant content:"
        return CodingDictionaryResult(
            confidence: 35,
            query: query,
            title: query,
            subtitle: "Relevant project content",
            kind: "Search Results",
            category: "Project",
            difficulty: "",
            overview: overview,
            definition: overview,
            summary: overview,
            syntax: "",
            examples: snippets,
            bestPractices: [],
            notes: refs.enumerated().map { "\($0.offset + 1). \($0.element)" },
            seeAlso: [],
            references: refs,
            appleDocsSummary: "",
            swiftVersion: "",
            alternativeAPIs: [],
            codeSnippet: "",
            complexity: "",
            memoryConsiderations: ""
        )
    }

    private static func excerpt(from relPath: String, terms: Set<String>, maxLines: Int = 12) -> String? {
        guard let root = ProjectSessionStore.shared.activeProject?.directoryURL else { return nil }
        let url = root.appendingPathComponent(relPath)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let lines = text.components(separatedBy: .newlines)
        var bestStart = -1
        var bestScore = 0
        for i in 0..<lines.count {
            let toks = Set(LocalDictionaryEngine.terms(of: lines[i]))
            let overlap = toks.intersection(terms).count
            if overlap > bestScore { bestScore = overlap; bestStart = i }
        }
        guard bestStart >= 0 else { return nil }
        let start = max(0, bestStart - 2)
        let end = min(lines.count, start + maxLines)
        return lines[start..<end].joined(separator: "\n")
    }

    private static func parseParameters(from signature: String) -> [DictionaryParameter] {
        guard let open = signature.firstIndex(of: "("), let close = signature[open...].firstIndex(of: ")") else { return [] }
        let inner = signature[signature.index(after: open)..<close]
        var params: [DictionaryParameter] = []
        for part in inner.split(separator: ",") {
            let piece = part.trimmingCharacters(in: .whitespaces)
            guard !piece.isEmpty else { continue }
            var name = piece
            var type = ""
            if let colon = piece.firstIndex(of: ":") {
                name = String(piece[..<colon]).trimmingCharacters(in: .whitespaces)
                type = String(piece[piece.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                if let space = type.firstIndex(of: " ") { type = String(type[..<space]) }
            }
            let label = name.split(separator: " ").last.map(String.init) ?? name
            params.append(DictionaryParameter(name: label, type: type, description: ""))
        }
        return params
    }

    private static func parseReturnValue(from signature: String) -> DictionaryReturnValue {
        guard let arrow = signature.range(of: "->") else { return DictionaryReturnValue(type: "", description: "") }
        var rest = String(signature[arrow.upperBound...])
        if let brace = rest.firstIndex(where: { $0 == "{" || $0 == "\n" }) {
            rest = String(rest[..<brace])
        }
        let type = rest.trimmingCharacters(in: .whitespaces)
        return DictionaryReturnValue(type: type, description: type.isEmpty ? "" : "Return value of type \(type)")
    }

    static func terms(of text: String) -> [String] {
        var out: [String] = []
        var current = ""
        func flush() {
            if current.count > 1 { out.append(current.lowercased()) }
            current = ""
        }
        for scalar in text.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                if let ch = Character(scalar).unicodeScalars.first,
                   ch.properties.isUppercase, !current.isEmpty,
                   let last = current.last, last.isLowercase || last.isNumber {
                    flush()
                }
                current.unicodeScalars.append(scalar)
            } else if scalar == "_" || scalar == "-" {
                flush()
            } else {
                flush()
            }
        }
        flush()
        return out
    }

    static func queryTerms(_ query: String) -> [String] {
        var terms = terms(of: query)
        terms = terms.filter { !$0.isEmpty && !stopWords.contains($0) }
        var seen = Set<String>()
        return terms.filter { seen.insert($0).inserted }
    }

    private static let stopWords: Set<String> = [
        "the", "a", "an", "and", "or", "of", "to", "in", "on", "for", "with", "is", "are",
        "was", "were", "be", "been", "it", "its", "this", "that", "what", "how", "why",
        "when", "where", "which", "who", "does", "do", "did", "can", "could", "should",
        "would", "will", "may", "might", "must", "shall", "not", "no", "yes", "if", "then",
        "else", "as", "at", "by", "from", "into", "about", "use", "used", "using", "get",
        "set", "make", "made", "i", "me", "my", "we", "our", "you", "your", "they", "their"
    ]
}
