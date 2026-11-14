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
        func keyed(_ entries: [ApiSurfaceEntry]) -> [String: ApiSurfaceEntry] {
            var counts: [String: Int] = [:]
            var result: [String: ApiSurfaceEntry] = [:]
            for entry in entries {
                let base = entry.kind.rawValue + "|" + entry.name + "|" + entry.path
                let occurrence = counts[base, default: 0]
                counts[base] = occurrence + 1
                result[base + "#" + String(occurrence)] = entry
            }
            return result
        }
        let oldMap = keyed(oldSurface)
        let newMap = keyed(newSurface)
        var changes: [CompatibilityChange] = []
        for key in oldMap.keys.sorted() {
            guard let oldEntry = oldMap[key] else { continue }
            if let newEntry = newMap[key] {
                if oldEntry.signature != newEntry.signature {
                    changes.append(CompatibilityChange(kind: oldEntry.kind, name: oldEntry.name, change: .changed, breaking: true, oldSignature: oldEntry.signature, newSignature: newEntry.signature, path: oldEntry.path))
                }
            } else {
                changes.append(CompatibilityChange(kind: oldEntry.kind, name: oldEntry.name, change: .removed, breaking: true, oldSignature: oldEntry.signature, newSignature: nil, path: oldEntry.path))
            }
        }
        for key in newMap.keys.sorted() where oldMap[key] == nil {
            guard let newEntry = newMap[key] else { continue }
            changes.append(CompatibilityChange(kind: newEntry.kind, name: newEntry.name, change: .added, breaking: false, oldSignature: nil, newSignature: newEntry.signature, path: newEntry.path))
        }
        return changes.sorted { ($0.name, $0.path) < ($1.name, $1.path) }
    }
}
