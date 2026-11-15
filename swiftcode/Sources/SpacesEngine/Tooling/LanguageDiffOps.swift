import Foundation

public struct LanguageDiffOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public enum ChangeKind: String, Codable, Sendable {
        case added
        case removed
        case changed
    }

    public struct DeclarationChange: Codable, Sendable, Equatable {
        public var kind: SwiftDeclarationParser.DeclarationKind
        public var name: String
        public var change: ChangeKind
        public var oldSignature: String?
        public var newSignature: String?
        public var oldLine: Int?
        public var newLine: Int?
        public var path: String

        public init(kind: SwiftDeclarationParser.DeclarationKind, name: String, change: ChangeKind, oldSignature: String? = nil, newSignature: String? = nil, oldLine: Int? = nil, newLine: Int? = nil, path: String) {
            self.kind = kind
            self.name = name
            self.change = change
            self.oldSignature = oldSignature
            self.newSignature = newSignature
            self.oldLine = oldLine
            self.newLine = newLine
            self.path = path
        }
    }

    public func declarations(at rev: String, path: String) throws -> [SwiftDeclarationParser.SwiftDeclaration] {
        guard let text = try ToolingStorage.blobText(repo: repo, rev: rev, path: path) else { return [] }
        return SwiftDeclarationParser.parse(text)
    }

    public func structuralDiff(from: String, to: String, path: String) throws -> [DeclarationChange] {
        let oldDeclarations = try declarations(at: from, path: path)
        let newDeclarations = try declarations(at: to, path: path)
        return Self.diffDeclarations(old: oldDeclarations, new: newDeclarations, path: path)
    }

    public static func diffDeclarations(old: [SwiftDeclarationParser.SwiftDeclaration], new: [SwiftDeclarationParser.SwiftDeclaration], path: String) -> [DeclarationChange] {
        func keyed(_ declarations: [SwiftDeclarationParser.SwiftDeclaration]) -> [String: SwiftDeclarationParser.SwiftDeclaration] {
            var counts: [String: Int] = [:]
            var result: [String: SwiftDeclarationParser.SwiftDeclaration] = [:]
            for declaration in declarations {
                let base = declaration.kind.rawValue + "|" + declaration.name
                let occurrence = counts[base, default: 0]
                counts[base] = occurrence + 1
                result[base + "#" + String(occurrence)] = declaration
            }
            return result
        }
        let oldMap = keyed(old)
        let newMap = keyed(new)
        var changes: [DeclarationChange] = []
        for key in oldMap.keys.sorted() {
            guard let oldDeclaration = oldMap[key] else { continue }
            if let newDeclaration = newMap[key] {
                if oldDeclaration.signature != newDeclaration.signature || oldDeclaration.body != newDeclaration.body {
                    changes.append(DeclarationChange(kind: oldDeclaration.kind, name: oldDeclaration.name, change: .changed, oldSignature: oldDeclaration.signature, newSignature: newDeclaration.signature, oldLine: oldDeclaration.line, newLine: newDeclaration.line, path: path))
                }
            } else {
                changes.append(DeclarationChange(kind: oldDeclaration.kind, name: oldDeclaration.name, change: .removed, oldSignature: oldDeclaration.signature, newSignature: nil, oldLine: oldDeclaration.line, newLine: nil, path: path))
            }
        }
        for key in newMap.keys.sorted() where oldMap[key] == nil {
            guard let newDeclaration = newMap[key] else { continue }
            changes.append(DeclarationChange(kind: newDeclaration.kind, name: newDeclaration.name, change: .added, oldSignature: nil, newSignature: newDeclaration.signature, oldLine: nil, newLine: newDeclaration.line, path: path))
        }
        return changes.sorted { ($0.name, $0.kind.rawValue) < ($1.name, $1.kind.rawValue) }
    }
}
