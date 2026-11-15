import Foundation

public struct ApiCompatibilityOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct ApiSurfaceEntry: Codable, Sendable, Equatable {
        public var kind: SwiftDeclarationParser.DeclarationKind
        public var name: String
        public var signature: String
        public var path: String
        public var line: Int

        public init(kind: SwiftDeclarationParser.DeclarationKind, name: String, signature: String, path: String, line: Int) {
            self.kind = kind
            self.name = name
            self.signature = signature
            self.path = path
            self.line = line
        }
    }

    public struct CompatibilityChange: Codable, Sendable, Equatable {
        public var kind: SwiftDeclarationParser.DeclarationKind
        public var name: String
        public var change: LanguageDiffOps.ChangeKind
        public var breaking: Bool
        public var oldSignature: String?
        public var newSignature: String?
        public var path: String

        public init(kind: SwiftDeclarationParser.DeclarationKind, name: String, change: LanguageDiffOps.ChangeKind, breaking: Bool, oldSignature: String? = nil, newSignature: String? = nil, path: String) {
            self.kind = kind
            self.name = name
            self.change = change
            self.breaking = breaking
            self.oldSignature = oldSignature
            self.newSignature = newSignature
            self.path = path
        }
    }

    public func publicApiSurface(rev: String) throws -> [ApiSurfaceEntry] {
        var entries: [ApiSurfaceEntry] = []
        for path in try ToolingStorage.swiftPaths(repo: repo, rev: rev) {
            guard let text = try ToolingStorage.blobText(repo: repo, rev: rev, path: path) else { continue }
            let inPublicSurface = path.hasPrefix("Public/") || path.contains("/Public/")
            for declaration in SwiftDeclarationParser.parse(text) where declaration.isPublic || inPublicSurface {
                entries.append(ApiSurfaceEntry(kind: declaration.kind, name: declaration.name, signature: declaration.signature, path: path, line: declaration.line))
            }
        }
        return entries.sorted { ($0.path, $0.name) < ($1.path, $1.name) }
    }

    public func compatibilityBetween(from: String, to: String) throws -> [CompatibilityChange] {
        let oldSurface = try publicApiSurface(rev: from)
        let newSurface = try publicApiSurface(rev: to)
        let newProtocols = try protocolSpans(rev: to)
        func grouped(_ entries: [ApiSurfaceEntry]) -> [String: [ApiSurfaceEntry]] {
            var result: [String: [ApiSurfaceEntry]] = [:]
            for entry in entries {
                result[entry.kind.rawValue + "|" + entry.name + "|" + entry.path, default: []].append(entry)
            }
            return result
        }
        func insideProtocol(_ entry: ApiSurfaceEntry) -> Bool {
            newProtocols.contains { $0.path == entry.path && entry.line > $0.start && entry.line < $0.end }
        }
        let oldGroups = grouped(oldSurface)
        let newGroups = grouped(newSurface)
        var changes: [CompatibilityChange] = []
        for key in oldGroups.keys.sorted() {
            guard let oldEntries = oldGroups[key] else { continue }
            var unmatchedNew = newGroups[key] ?? []
            for oldEntry in oldEntries {
                if let index = unmatchedNew.firstIndex(where: { $0.signature == oldEntry.signature }) {
                    unmatchedNew.remove(at: index)
                } else if let replacement = unmatchedNew.first {
                    unmatchedNew.remove(at: 0)
                    changes.append(CompatibilityChange(kind: oldEntry.kind, name: oldEntry.name, change: .changed, breaking: true, oldSignature: oldEntry.signature, newSignature: replacement.signature, path: oldEntry.path))
                } else {
                    changes.append(CompatibilityChange(kind: oldEntry.kind, name: oldEntry.name, change: .removed, breaking: true, oldSignature: oldEntry.signature, newSignature: nil, path: oldEntry.path))
                }
            }
            for newEntry in unmatchedNew {
                changes.append(CompatibilityChange(kind: newEntry.kind, name: newEntry.name, change: .added, breaking: insideProtocol(newEntry), oldSignature: nil, newSignature: newEntry.signature, path: newEntry.path))
            }
        }
        for key in newGroups.keys.sorted() where oldGroups[key] == nil {
            for newEntry in newGroups[key] ?? [] {
                changes.append(CompatibilityChange(kind: newEntry.kind, name: newEntry.name, change: .added, breaking: insideProtocol(newEntry), oldSignature: nil, newSignature: newEntry.signature, path: newEntry.path))
            }
        }
        return changes.sorted { ($0.name, $0.path) < ($1.name, $1.path) }
    }

    private struct ProtocolSpan {
        var path: String
        var start: Int
        var end: Int
    }

    private func protocolSpans(rev: String) throws -> [ProtocolSpan] {
        var spans: [ProtocolSpan] = []
        for path in try ToolingStorage.swiftPaths(repo: repo, rev: rev) {
            guard let text = try ToolingStorage.blobText(repo: repo, rev: rev, path: path) else { continue }
            for declaration in SwiftDeclarationParser.parse(text)
            where declaration.kind == .protocolType {
                let bodyLines = declaration.body.components(separatedBy: "\n").count
                spans.append(ProtocolSpan(path: path, start: declaration.line,
                                          end: declaration.line + max(1, bodyLines)))
            }
        }
        return spans
    }
}
