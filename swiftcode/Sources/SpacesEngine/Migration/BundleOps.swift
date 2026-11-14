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
