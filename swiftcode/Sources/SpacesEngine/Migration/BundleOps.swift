import Crypto
import Foundation












public enum BundleOps {

    public struct BundleReport: Sendable, Encodable {
        public var objectCount: Int
        public var refs: [String: String]
        public var created: Int64
    }

    
    
    public static func create(repo: Repository, output: String,
                              refNames: [String] = []) throws {
        
        var seeds: [ObjectID] = []
        var refs: [String: String] = [:]
        if refNames.isEmpty {
            for ref in try repo.refs.allRefs() {
                seeds.append(ref.oid)
                refs[ref.name] = ref.oid.hex
            }
        } else {
            for name in refNames {
                let oid = try repo.refs.resolve(name, objects: repo.objects)
                seeds.append(oid)
                let full = name.hasPrefix("refs/") ? name : "refs/heads/\(name)"
                refs[full] = oid.hex
            }
        }
        let reachable = try repo.objects.reachable(from: seeds)

        struct Header: Codable {
            var refs: [String: String]
            var objects: [String]
            var created: Int64
            var message: String
        }
        let header = Header(refs: refs,
                            objects: reachable.map(\.hex).sorted(),
                            created: Int64(Date().timeIntervalSince1970),
                            message: "spaces bundle")
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let headerData = try encoder.encode(header)

        var out = Data()
        out.append(contentsOf: [0x53, 0x50, 0x42, 0x44]) 
        var version: UInt32 = 1
        withUnsafeBytes(of: version.bigEndian) { out.append(contentsOf: $0) }
        var headerLen = UInt64(headerData.count).bigEndian
        withUnsafeBytes(of: &headerLen) { out.append(contentsOf: $0) }
        out.append(headerData)

        
        for id in reachable.sorted() {
            let stored = try repo.objects.read(id)
            let encoded = ObjectCoding.encode(StoredObject(type: stored.type, payload: stored.payload))
            var len = UInt64(encoded.count).bigEndian
            withUnsafeBytes(of: &len) { out.append(contentsOf: $0) }
            out.append(encoded)
        }
        try out.write(to: URL(fileURLWithPath: output), options: .atomic)
    }

    
    public static func inspect(path: String) throws -> BundleReport {
        let (header, _) = try readBundle(path: path)
        return BundleReport(objectCount: header.objects.count,
                            refs: header.refs, created: header.created)
    }

    
    public static func verify(path: String) throws -> BundleReport {
        let (header, objects) = try readBundle(path: path)
        var seen = Set<String>()
        for (idHex, stored) in objects {
            seen.insert(idHex)
            let computed = ObjectID.compute(type: stored.type, payload: stored.payload)
            guard computed.hex == idHex else {
                throw SpacesError.objectCorrupt(idHex)
            }
        }
        
        for (_, oidHex) in header.refs where !seen.contains(oidHex) {
            throw SpacesError.objectNotFound(oidHex)
        }
        return BundleReport(objectCount: objects.count,
                            refs: header.refs, created: header.created)
    }

    
    @discardableResult
    public static func importBundle(into repo: Repository, path: String) throws -> BundleReport {
        let (header, objects) = try readBundle(path: path)
        var written = 0
        for (idHex, stored) in objects {
            let computed = ObjectID.compute(type: stored.type, payload: stored.payload)
            guard computed.hex == idHex else { throw SpacesError.objectCorrupt(idHex) }
            if !repo.objects.exists(computed) {
                _ = try repo.objects.write(type: stored.type, payload: stored.payload)
                written += 1
            }
        }
        for (name, oidHex) in header.refs {
            guard let oid = try? ObjectID(validating: oidHex) else { continue }
            _ = try repo.refs.updateRef(name, to: oid)
        }
        return BundleReport(objectCount: objects.count, refs: header.refs,
                            created: header.created)
    }

    

    struct BundleHeader: Codable {
        var refs: [String: String]
        var objects: [String]
        var created: Int64
        var message: String
    }

    private static func readBundle(path: String) throws
        -> (BundleHeader, [(String, StoredObject)]) {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        guard data.count >= 16 else { throw SpacesError.invalidObject("bundle too short") }
        guard Array(data.prefix(4)) == [0x53, 0x50, 0x42, 0x44] else {
            throw SpacesError.invalidObject("bad bundle magic")
        }
        let version = data[4..<8].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        guard version == 1 else { throw SpacesError.invalidObject("unsupported bundle version \(version)") }
        let headerLen = data[8..<16].reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        let headerStart = 16
        let headerEnd = headerStart + Int(headerLen)
        guard headerEnd <= data.count else { throw SpacesError.invalidObject("truncated bundle header") }
        let header = try JSONDecoder().decode(BundleHeader.self,
                                              from: data.subdata(in: headerStart..<headerEnd))
        
        var objects: [(String, StoredObject)] = []
        var pos = headerEnd
        while pos + 8 <= data.count {
            let len = data[pos..<(pos + 8)].reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
            pos += 8
            let end = pos + Int(len)
            guard end <= data.count else { throw SpacesError.invalidObject("truncated object record") }
            let record = data.subdata(in: pos..<end)
            pos = end
            let stored = try ObjectCoding.decode(record)
            let id = ObjectID.compute(type: stored.type, payload: stored.payload)
            objects.append((id.hex, stored))
        }
        return (header, objects)
    }
}


public enum ArchiveOps {
    public static func create(repo: Repository, rev: String, output: String) throws {
        let oid = try repo.resolveRevision(rev)
        let commit = try repo.commitObject(oid)
        let flat = try TreeBuilder.flattenTree(repo: repo, treeOID: commit.tree)

        var tar = Data()
        for (path, entry) in flat.sorted(by: { $0.key < $1.key }) {
            let data: Data
            var typeflag: UInt8 = 0 
            var linkname = ""
            if entry.mode.isSymlink {
                data = try repo.blobData(entry.oid)
                linkname = String(decoding: data, as: UTF8.self)
                typeflag = 2
            } else {
                data = try repo.blobData(entry.oid)
            }
            tar.append(contentsOf: try tarHeader(name: path, size: Int64(data.count),
                                                 mode: entry.mode == .executable ? 0o755 : 0o644,
                                                 typeflag: typeflag, linkname: linkname))
            tar.append(data)
            
            let pad = (512 - (data.count % 512)) % 512
            tar.append(Data(repeating: 0, count: pad))
        }
        
        tar.append(Data(repeating: 0, count: 1024))
        try tar.write(to: URL(fileURLWithPath: output), options: .atomic)
    }

    public static func extract(archive: String, to destination: String) throws -> [String] {
        let data = try Data(contentsOf: URL(fileURLWithPath: archive))
        let destURL = URL(fileURLWithPath: destination)
        try FileManager.default.createDirectory(at: destURL, withIntermediateDirectories: true)
        let destStandard = destURL.standardized.path
        var extracted: [String] = []
        var pos = 0
        var pendingLongName: String?
        var pendingLongLink: String?
        var pendingPaxPath: String?
        var pendingPaxLinkPath: String?
        var globalPaxPath: String?
        var globalPaxLinkPath: String?
        while pos + 512 <= data.count {
            let header = [UInt8](data[pos..<(pos + 512)])
            if header.allSatisfy({ $0 == 0 }) { break }
            guard verifyTarChecksum(header) else {
                throw SpacesError.invalidObject("bad tar header checksum at offset \(pos)")
            }
            let typeflag = header[156]
            let isMetaEntry = typeflag == 0x78 || typeflag == 0x67 || typeflag == 0x4C || typeflag == 0x4B
            var name = tarString(header, 0, 100)
            let prefix = tarString(header, 345, 155)
            if !prefix.isEmpty { name = prefix + "/" + name }
            if !isMetaEntry, let long = pendingLongName { name = long; pendingLongName = nil }
            else if let long = pendingLongName { name = long }
            if isMetaEntry {
                if let pax = pendingPaxPath { name = pax }
                else if let pax = globalPaxPath { name = pax }
            } else if let pax = pendingPaxPath { name = pax; pendingPaxPath = nil }
            else if let pax = globalPaxPath { name = pax }
            var linkName = tarString(header, 157, 100)
            if !isMetaEntry, let longLink = pendingLongLink { linkName = longLink; pendingLongLink = nil }
            else if let longLink = pendingLongLink { linkName = longLink }
            if isMetaEntry {
                if let paxLink = pendingPaxLinkPath { linkName = paxLink }
                else if let paxLink = globalPaxLinkPath { linkName = paxLink }
            } else if let paxLink = pendingPaxLinkPath { linkName = paxLink; pendingPaxLinkPath = nil }
            else if let paxLink = globalPaxLinkPath { linkName = paxLink }
            let size = try tarSize(header)
            let mode = tarOctal(header, 100, 8) ?? 0o644
            let mtime = tarOctal(header, 136, 12) ?? 0
            let dataStart = pos + 512
            let dataEnd = dataStart + size
            guard dataEnd <= data.count else {
                throw SpacesError.invalidObject("truncated tar entry \(name)")
            }
            let payload = data.subdata(in: dataStart..<dataEnd)
            switch typeflag {
            case 0x4C:
                pendingLongName = String(decoding: payload.prefix(while: { $0 != 0 }), as: UTF8.self)
            case 0x4B:
                pendingLongLink = String(decoding: payload.prefix(while: { $0 != 0 }), as: UTF8.self)
            case 0x78:
                let records = paxRecords(payload)
                if let path = records["path"] { pendingPaxPath = path }
                if let linkPath = records["linkpath"] { pendingPaxLinkPath = linkPath }
            case 0x67:
                let records = paxRecords(payload)
                if let path = records["path"] { globalPaxPath = path }
                if let linkPath = records["linkpath"] { globalPaxLinkPath = linkPath }
            case 0x30, 0x00:
                let target = try containedTarget(destStandard: destStandard, relative: name)
                try ensureNoSymlinkParent(target, destStandard: destStandard)
                try removeConflictingEntry(target)
                try FileManager.default.createDirectory(at: target.deletingLastPathComponent(),
                                                        withIntermediateDirectories: true)
                try payload.write(to: target, options: .atomic)
                try restoreAttributes(target, mode: mode, mtime: mtime)
                extracted.append(name)
            case 0x35:
                let target = try containedTarget(destStandard: destStandard, relative: name)
                try ensureNoSymlinkParent(target, destStandard: destStandard)
                try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
                try restoreAttributes(target, mode: mode, mtime: mtime)
                extracted.append(name)
            case 0x32:
                let target = try containedTarget(destStandard: destStandard, relative: name)
                try ensureNoSymlinkParent(target, destStandard: destStandard)
                try removeConflictingEntry(target)
                try FileManager.default.createDirectory(at: target.deletingLastPathComponent(),
                                                        withIntermediateDirectories: true)
                try FileManager.default.createSymbolicLink(atPath: target.path,
                                                           withDestinationPath: linkName)
                extracted.append(name)
            case 0x31:
                let target = try containedTarget(destStandard: destStandard, relative: name)
                let source = try containedTarget(destStandard: destStandard, relative: linkName)
                guard FileManager.default.fileExists(atPath: source.path) else {
                    throw SpacesError.migrationError("tar hard link target missing: \(linkName)")
                }
                try ensureNoSymlinkParent(target, destStandard: destStandard)
                try removeConflictingEntry(target)
                try FileManager.default.createDirectory(at: target.deletingLastPathComponent(),
                                                        withIntermediateDirectories: true)
                try FileManager.default.copyItem(at: source, to: target)
                extracted.append(name)
            default:
                throw SpacesError.migrationError("unsupported tar entry type \(typeflag) for \(name)")
            }
            pos = dataStart + ((size + 511) / 512) * 512
        }
        return extracted
    }

    private static func tarString(_ header: [UInt8], _ offset: Int, _ length: Int) -> String {
        let field = header[offset..<(offset + length)]
        let bytes = field.prefix(while: { $0 != 0 })
        return String(decoding: bytes, as: UTF8.self)
    }

    private static func paxRecords(_ payload: Data) -> [String: String] {
        var records: [String: String] = [:]
        var offset = 0
        while offset < payload.count {
            guard let space = payload[offset...].firstIndex(of: 0x20) else { break }
            let lengthText = String(decoding: payload[offset..<space], as: UTF8.self)
            guard let length = Int(lengthText.trimmingCharacters(in: .whitespaces)),
                  length > 0, offset + length <= payload.count else { break }
            let bodyEnd = payload[offset + length - 1] == 0x0A ? offset + length - 1 : offset + length
            let body = payload[(space + 1)..<bodyEnd]
            if let equals = body.firstIndex(of: 0x3D) {
                let key = String(decoding: body[body.startIndex..<equals], as: UTF8.self)
                let value = String(decoding: body[body.index(after: equals)..<body.endIndex], as: UTF8.self)
                records[key] = value
            }
            offset += length
        }
        return records
    }

    private static func tarOctal(_ header: [UInt8], _ offset: Int, _ length: Int) -> Int? {
        let field = Array(header[offset..<(offset + length)])
        if field.first == 0x80 {
            var value = 0
            for b in field.dropFirst() { value = (value << 8) | Int(b) }
            return value
        }
        let text = String(decoding: field, as: UTF8.self)
            .trimmingCharacters(in: CharacterSet(charactersIn: " \0"))
        guard !text.isEmpty else { return nil }
        return Int(text, radix: 8)
    }

    private static func tarSize(_ header: [UInt8]) throws -> Int {
        guard let size = tarOctal(header, 124, 12) else {
            throw SpacesError.invalidObject("bad tar size field")
        }
        return size
    }

    private static func verifyTarChecksum(_ header: [UInt8]) -> Bool {
        guard let stored = tarOctal(header, 148, 8) else { return false }
        var sum = 0
        for i in 0..<512 {
            sum += (i >= 148 && i < 156) ? 0x20 : Int(header[i])
        }
        return sum == stored
    }

    private static func containedTarget(destStandard: String, relative: String) throws -> URL {
        guard !relative.isEmpty else {
            throw SpacesError.invalidObject("empty tar entry name")
        }
        let components = relative.split(separator: "/", omittingEmptySubsequences: true)
        guard !components.contains("..") else {
            throw SpacesError.invalidObject("tar entry escapes destination: \(relative)")
        }
        var target = URL(fileURLWithPath: destStandard)
        for comp in components { target.appendPathComponent(String(comp)) }
        let standardized = target.standardized.path
        guard standardized == destStandard || standardized.hasPrefix(destStandard + "/") else {
            throw SpacesError.invalidObject("tar entry escapes destination: \(relative)")
        }
        return URL(fileURLWithPath: standardized)
    }

    private static func ensureNoSymlinkParent(_ target: URL, destStandard: String) throws {
        var current = target
        while current.path != destStandard && current.path.hasPrefix(destStandard + "/") {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: current.path),
               let type = attrs[.type] as? FileAttributeType, type == .typeSymbolicLink {
                throw SpacesError.invalidObject("tar entry passes through symlink: \(current.path)")
            }
            current = current.deletingLastPathComponent()
        }
    }

    private static func removeConflictingEntry(_ target: URL) throws {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: target.path),
              let type = attrs[.type] as? FileAttributeType else { return }
        if type == .typeDirectory {
            throw SpacesError.invalidObject("tar entry conflicts with directory: \(target.path)")
        }
        try FileManager.default.removeItem(at: target)
    }

    private static func restoreAttributes(_ target: URL, mode: Int, mtime: Int) throws {
        var attrs: [FileAttributeKey: Any] = [.posixPermissions: mode & 0o7777]
        if mtime > 0 {
            attrs[.modificationDate] = Date(timeIntervalSince1970: TimeInterval(mtime))
        }
        try FileManager.default.setAttributes(attrs, ofItemAtPath: target.path)
    }

    private static func tarHeader(name: String, size: Int64, mode: Int,
                                  typeflag: UInt8, linkname: String) throws -> Data {
        var header = [UInt8](repeating: 0, count: 512)
        func put(_ str: String, at offset: Int, len: Int) {
            let bytes = Array(str.utf8.prefix(len))
            for (i, b) in bytes.enumerated() { header[offset + i] = b }
        }
        func putOctal(_ value: Int64, at offset: Int, len: Int) {
            let s = String(value, radix: 8)
            let padded = String(repeating: "0", count: max(0, len - s.count - 1)) + s
            put(padded, at: offset, len: len)
        }
        put(name, at: 0, len: 100)
        putOctal(Int64(mode), at: 100, len: 8)
        putOctal(0, at: 108, len: 8)   
        putOctal(0, at: 116, len: 8)   
        putOctal(size, at: 124, len: 12)
        putOctal(Int64(Date().timeIntervalSince1970), at: 136, len: 12)
        
        for i in 148..<156 { header[i] = 0x20 }
        header[156] = typeflag
        put(linkname, at: 157, len: 100)
        put("ustar", at: 257, len: 6)
        put("00", at: 263, len: 2)
        
        var sum = 0
        for b in header { sum += Int(b) }
        let sumStr = String(format: "%06o", sum)
        let padded = String(repeating: "0", count: 6 - sumStr.count) + sumStr + "\0 "
        put(padded, at: 148, len: 8)
        return Data(header)
    }
}
