import Foundation

/// A reference (branch, tag, remote-tracking, snapshot) resolved to an object.
public struct Ref: Hashable, Sendable, Encodable {
    public let name: String   // e.g. "refs/heads/main"
    public let oid: ObjectID
    public var shortName: String {
        for prefix in ["refs/heads/", "refs/tags/", "refs/remotes/", "refs/snapshots/"] {
            if name.hasPrefix(prefix) { return String(name.dropFirst(prefix.count)) }
        }
        return name
    }
    public var kind: RefKind {
        if name.hasPrefix("refs/heads/") { return .branch }
        if name.hasPrefix("refs/tags/") { return .tag }
        if name.hasPrefix("refs/remotes/") { return .remote }
        if name.hasPrefix("refs/snapshots/") { return .snapshot }
        return .other
    }
}

public enum RefKind: Sendable { case branch, tag, remote, snapshot, other }

/// Manages `.spaces/HEAD`, loose refs, and packed-refs.
public final class RefDatabase: @unchecked Sendable {
    public let metaURL: URL

    public init(metaURL: URL) { self.metaURL = metaURL }

    private func refURL(_ name: String) -> URL {
        metaURL.appendingPathComponent(name)
    }

    private var packedRefsURL: URL { metaURL.appendingPathComponent("packed-refs") }

    public static func isValidRefName(_ name: String) -> Bool {
        guard !name.isEmpty, !name.hasPrefix("/"), !name.hasSuffix("/"),
              !name.contains(".."), !name.contains("//"),
              !name.contains(" "), !name.hasSuffix(".") else { return false }
        return name.allSatisfy { !$0.isNewline }
    }

    // MARK: - HEAD

    public func readHEAD() throws -> String {
        let url = metaURL.appendingPathComponent("HEAD")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            throw SpacesError.refNotFound("HEAD")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Returns the ref HEAD points at ("refs/heads/main") or nil when detached.
    public func symbolicHEAD() throws -> String? {
        let head = try readHEAD()
        if head.hasPrefix("ref: ") { return String(head.dropFirst(5)) }
        return nil
    }

    public func setHEAD(ref: String) throws {
        try atomicWrite(metaURL.appendingPathComponent("HEAD"),
                        contents: Data("ref: \(ref)\n".utf8))
    }

    public func setHEAD(oid: ObjectID) throws {
        try atomicWrite(metaURL.appendingPathComponent("HEAD"),
                        contents: Data("\(oid.hex)\n".utf8))
    }

    public func headOID(objects: ObjectStore) throws -> ObjectID? {
        let head = try readHEAD()
        if head.hasPrefix("ref: ") {
            // Unborn branch (ref doesn't exist yet) → nil.
            if let oid = try readRef(String(head.dropFirst(5))) { return oid }
            return nil
        }
        return try? ObjectID(validating: head)
    }

    // MARK: - Loose refs

    @discardableResult
    public func updateRef(_ name: String, to oid: ObjectID) throws -> ObjectID? {
        guard RefDatabase.isValidRefName(name) else { throw SpacesError.invalidRef(name) }
        let url = refURL(name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        let old = try? readRef(name)
        try atomicWrite(url, contents: Data("\(oid.hex)\n".utf8))
        return old
    }

    public func deleteRef(_ name: String) throws {
        let url = refURL(name)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        // Remove from packed-refs if present.
        if FileManager.default.fileExists(atPath: packedRefsURL.path) {
            let lines = (try? String(contentsOf: packedRefsURL, encoding: .utf8))?
                .components(separatedBy: "\n") ?? []
            let kept = lines.filter { !$0.hasSuffix(" \(name)") && !$0.hasSuffix("\t\(name)") }
            if kept.count != lines.count {
                try atomicWrite(packedRefsURL, contents: Data(kept.joined(separator: "\n").utf8))
            }
        }
    }

    public func readRef(_ name: String) throws -> ObjectID? {
        // Loose first.
        let url = refURL(name)
        if let text = try? String(contentsOf: url, encoding: .utf8),
           let hex = text.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\n").first {
            return try? ObjectID(validating: String(hex))
        }
        // Then packed-refs.
        if let packed = try? String(contentsOf: packedRefsURL, encoding: .utf8) {
            for line in packed.components(separatedBy: "\n") {
                let parts = line.split(separator: " ")
                if parts.count == 2, parts[1] == name {
                    return try? ObjectID(validating: String(parts[0]))
                }
            }
        }
        return nil
    }

    public func resolve(_ name: String, objects: ObjectStore) throws -> ObjectID {
        if let oid = try readRef(name) { return oid }
        // Allow short names like "main" -> refs/heads/main.
        for candidate in ["refs/\(name)", "refs/heads/\(name)", "refs/tags/\(name)",
                          "refs/remotes/\(name)"] {
            if let oid = try readRef(candidate) { return oid }
        }
        // Try object ID abbreviation.
        return try ObjectID.resolve(name, in: objects)
    }

    public func allRefs() throws -> [Ref] {
        var result: [Ref] = []
        let fm = FileManager.default
        // Loose refs under refs/.
        let refsRoot = metaURL.appendingPathComponent("refs")
        if let enumerator = fm.enumerator(atPath: refsRoot.path) {
            for case let rel as String in enumerator {
                let full = refsRoot.appendingPathComponent(rel)
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: full.path, isDirectory: &isDir), !isDir.boolValue else { continue }
                let name = "refs/" + rel
                if let oid = try readRef(name) {
                    result.append(Ref(name: name, oid: oid))
                }
            }
        }
        // packed-refs (dedupe by name, loose wins).
        if let packed = try? String(contentsOf: packedRefsURL, encoding: .utf8) {
            for line in packed.components(separatedBy: "\n") {
                guard !line.hasPrefix("#"), !line.hasPrefix("^") else { continue }
                let parts = line.split(separator: " ", maxSplits: 1)
                guard parts.count == 2, let oid = try? ObjectID(validating: String(parts[0])) else { continue }
                let name = String(parts[1])
                if !result.contains(where: { $0.name == name }) {
                    result.append(Ref(name: name, oid: oid))
                }
            }
        }
        return result.sorted { $0.name < $1.name }
    }

    public func branches() throws -> [Ref] {
        try allRefs().filter { $0.kind == .branch }
    }

    public func tags() throws -> [Ref] {
        try allRefs().filter { $0.kind == .tag }
    }

    /// Current branch name, or nil when HEAD is detached or unborn.
    public func currentBranch() throws -> String? {
        guard let sym = try symbolicHEAD() else { return nil }
        guard sym.hasPrefix("refs/heads/") else { return nil }
        return String(sym.dropFirst("refs/heads/".count))
    }

    // MARK: - Helpers

    func atomicWrite(_ url: URL, contents: Data) throws {
        let temp = url.appendingPathExtension("tmp-\(UUID().uuidString)")
        try contents.write(to: temp, options: .atomic)
        _ = try? FileManager.default.removeItem(at: url)
        try FileManager.default.moveItem(at: temp, to: url)
    }
}
