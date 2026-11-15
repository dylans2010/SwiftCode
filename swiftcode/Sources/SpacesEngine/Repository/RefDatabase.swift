import Foundation

public struct Ref: Hashable, Sendable, Encodable {
    public let name: String
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

public final class RefDatabase: @unchecked Sendable {
    public let metaURL: URL

    public init(metaURL: URL) { self.metaURL = metaURL }

    private func refURL(_ name: String) -> URL {
        metaURL.appendingPathComponent(name)
    }

    private var packedRefsURL: URL { metaURL.appendingPathComponent("packed-refs") }

    public static func isValidRefName(_ name: String) -> Bool {
        guard !name.isEmpty, name != "HEAD",
              !name.hasPrefix("/"), !name.hasSuffix("/"),
              !name.contains(".."), !name.contains("//"),
              !name.contains(" "), !name.hasSuffix("."),
              !name.contains("@{") else { return false }
        for scalar in name.unicodeScalars {
            let value = scalar.value
            if value < 0x20 || value == 0x7f { return false }
            if scalar == "~" || scalar == "^" || scalar == ":" || scalar == "?"
                || scalar == "*" || scalar == "[" || scalar == "\\" { return false }
        }
        for component in name.split(separator: "/") {
            if component.hasPrefix(".") || component.hasSuffix(".lock") { return false }
        }
        return true
    }

    public func readHEAD() throws -> String {
        let url = metaURL.appendingPathComponent("HEAD")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            throw SpacesError.refNotFound("HEAD")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

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
            return try readRef(String(head.dropFirst(5)))
        }
        return try ObjectID(validating: head)
    }

    @discardableResult
    public func updateRef(_ name: String, to oid: ObjectID) throws -> ObjectID? {
        guard RefDatabase.isValidRefName(name) else { throw SpacesError.invalidRef(name) }
        let url = refURL(name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        var old: ObjectID? = nil
        do { old = try readRef(name) } catch { old = nil }
        try atomicWrite(url, contents: Data("\(oid.hex)\n".utf8))
        return old
    }

    public func deleteRef(_ name: String) throws {
        let url = refURL(name)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        if FileManager.default.fileExists(atPath: packedRefsURL.path) {
            guard let text = try? String(contentsOf: packedRefsURL, encoding: .utf8) else { return }
            let lines = text.components(separatedBy: "\n")
            var kept: [String] = []
            var index = 0
            while index < lines.count {
                let parts = lines[index].split(whereSeparator: { $0 == " " || $0 == "\t" })
                if parts.count == 2, String(parts[1]) == name {
                    index += 1
                    if index < lines.count, lines[index].hasPrefix("^") { index += 1 }
                    continue
                }
                kept.append(lines[index])
                index += 1
            }
            if kept.count != lines.count {
                let out = kept.joined(separator: "\n")
                try atomicWrite(packedRefsURL, contents: Data(out.utf8))
            }
        }
    }

    public func readRef(_ name: String) throws -> ObjectID? {
        let url = refURL(name)
        if FileManager.default.fileExists(atPath: url.path) {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                throw SpacesError.ioError("cannot read ref \(name)")
            }
            let hex = text.trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: "\n").first.map(String.init) ?? ""
            guard !hex.isEmpty else { throw SpacesError.invalidRef("ref \(name) is empty") }
            do {
                return try ObjectID(validating: hex)
            } catch {
                throw SpacesError.invalidRef("ref \(name) is malformed: '\(hex)'")
            }
        }
        if let packed = try? String(contentsOf: packedRefsURL, encoding: .utf8) {
            for line in packed.components(separatedBy: "\n") {
                let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
                if parts.count == 2, parts[1] == name {
                    do {
                        return try ObjectID(validating: String(parts[0]))
                    } catch {
                        throw SpacesError.invalidRef("packed ref \(name) is malformed")
                    }
                }
            }
        }
        return nil
    }

    public func resolve(_ name: String, objects: ObjectStore) throws -> ObjectID {
        if let oid = try readRef(name) { return oid }
        for candidate in ["refs/\(name)", "refs/heads/\(name)", "refs/tags/\(name)",
                          "refs/remotes/\(name)"] {
            if let oid = try readRef(candidate) { return oid }
        }
        return try ObjectID.resolve(name, in: objects)
    }

    public func allRefs() throws -> [Ref] {
        var result: [Ref] = []
        let fm = FileManager.default
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
        if let packed = try? String(contentsOf: packedRefsURL, encoding: .utf8) {
            for line in packed.components(separatedBy: "\n") {
                guard !line.hasPrefix("#"), !line.hasPrefix("^") else { continue }
                let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
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

    public func currentBranch() throws -> String? {
        guard let sym = try symbolicHEAD() else { return nil }
        guard sym.hasPrefix("refs/heads/") else { return nil }
        return String(sym.dropFirst("refs/heads/".count))
    }

    func atomicWrite(_ url: URL, contents: Data) throws {
        try AtomicFileIO.writeAtomically(contents, to: url)
    }
}
