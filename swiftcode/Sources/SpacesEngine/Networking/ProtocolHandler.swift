import Foundation

public struct SpacesProtocolHandler: Sendable {
    public let repo: Repository

    public init(repo: Repository) {
        self.repo = repo
    }

    public static func jsonInt(_ value: Any?) -> Int64? {
        if let number = value as? NSNumber {
            return number.int64Value
        }
        if let int = value as? Int {
            return Int64(int)
        }
        if let int64 = value as? Int64 {
            return int64
        }
        return nil
    }

    public func handle(_ message: [String: Any]) throws -> [String: Any] {
        try repo.withLock {
            guard let op = message["op"] as? String else {
                throw SpacesError.protocolError("missing op")
            }
            switch op {
            case "hello":
                return ["v": RepositoryFormat.protocolVersion, "op": "hello",
                        "caps": ["objects-v1", "refs-v1", "lfs-v1"],
                        "repo": repo.worktreeURL.lastPathComponent]
            case "advertise-refs":
                let refs = try repo.refs.allRefs().map {
                    ["name": $0.name, "oid": $0.oid.hex] as [String: Any]
                }
                return ["v": RepositoryFormat.protocolVersion, "op": "refs", "refs": refs]
            case "want":
                let oids = (message["oids"] as? [String]) ?? []
                let haves = (message["haves"] as? [String]) ?? []
                let objects = try producePack(repo: repo, wants: oids, haves: haves)
                return ["v": RepositoryFormat.protocolVersion, "op": "pack", "objects": objects]
            case "update-refs":
                let refs = (message["refs"] as? [[String: Any]]) ?? []
                for r in refs {
                    guard let name = r["name"] as? String, let hex = r["oid"] as? String,
                          let oid = try? ObjectID(validating: hex) else { continue }
                    _ = try repo.refs.updateRef(name, to: oid)
                }
                return ["v": RepositoryFormat.protocolVersion, "op": "ok"]
            case "have":
                let oids = (message["oids"] as? [String]) ?? []
                var present: [String] = []
                for h in oids {
                    if let oid = try? ObjectID(validating: h), repo.objects.exists(oid) {
                        present.append(h)
                    }
                }
                return ["v": RepositoryFormat.protocolVersion, "op": "ack", "oids": present]
            case "store":
                let objects = (message["objects"] as? [[String: Any]]) ?? []
                for o in objects {
                    guard let hex = o["id"] as? String,
                          let typeRaw = o["type"] as? String,
                          let type = ObjectType(rawValue: typeRaw),
                          let b64 = o["data"] as? String,
                          let payload = Data(base64Encoded: b64),
                          let oid = try? ObjectID(validating: hex) else { continue }
                    guard ObjectID.compute(type: type, payload: payload) == oid else { continue }
                    _ = try repo.objects.write(type: type, payload: payload)
                }
                return ["v": RepositoryFormat.protocolVersion, "op": "ok"]
            case "delete-ref":
                return try handleDeleteRef(message)
            case "lfs-list":
                let objects = try LfsLocalStore.list(repo: repo).map {
                    ["oid": $0.oid, "size": $0.size] as [String: Any]
                }
                return ["v": RepositoryFormat.protocolVersion, "op": "lfs-list", "objects": objects]
            case "lfs-info":
                return try handleLfsInfo(message)
            case "lfs-get":
                return try handleLfsGet(message)
            case "lfs-put":
                return try handleLfsPut(message)
            default:
                throw SpacesError.protocolError("unknown op: \(op)")
            }
        }
    }

    private func handleDeleteRef(_ message: [String: Any]) throws -> [String: Any] {
        let names = (message["refs"] as? [String]) ?? []
        guard !names.isEmpty else {
            throw SpacesError.protocolError("delete-ref requires at least one ref")
        }
        let current = try? repo.refs.symbolicHEAD()
        var deleted: [String] = []
        for name in names {
            guard RefDatabase.isValidRefName(name) else {
                throw SpacesError.invalidRef(name)
            }
            if name == current {
                throw SpacesError.invalidArgument("cannot delete the checked-out branch \(name)")
            }
            guard try repo.refs.readRef(name) != nil else {
                throw SpacesError.refNotFound(name)
            }
            try repo.refs.deleteRef(name)
            deleted.append(name)
        }
        return ["v": RepositoryFormat.protocolVersion, "op": "ok", "deleted": deleted]
    }

    private func handleLfsInfo(_ message: [String: Any]) throws -> [String: Any] {
        guard let oid = message["oid"] as? String, LfsLocalStore.isValidOID(oid) else {
            throw SpacesError.protocolError("lfs-info missing or invalid oid")
        }
        let objectURL = LfsLocalStore.objectURL(repo: repo, oid: oid)
        if let size = LfsLocalStore.fileSize(at: objectURL) {
            return ["v": RepositoryFormat.protocolVersion, "op": "lfs-info",
                    "oid": oid, "size": size, "complete": true]
        }
        let partURL = LfsLocalStore.partURL(repo: repo, oid: oid)
        if let size = LfsLocalStore.fileSize(at: partURL) {
            return ["v": RepositoryFormat.protocolVersion, "op": "lfs-info",
                    "oid": oid, "size": size, "complete": false]
        }
        return ["v": RepositoryFormat.protocolVersion, "op": "lfs-info",
                "oid": oid, "size": 0, "complete": false]
    }

    private func handleLfsGet(_ message: [String: Any]) throws -> [String: Any] {
        guard let oid = message["oid"] as? String, LfsLocalStore.isValidOID(oid) else {
            throw SpacesError.protocolError("lfs-get missing or invalid oid")
        }
        let offset = Self.jsonInt(message["offset"]) ?? 0
        let url = LfsLocalStore.objectURL(repo: repo, oid: oid)
        guard let size = LfsLocalStore.fileSize(at: url) else {
            throw SpacesError.lfsError("lfs object not found: \(oid)")
        }
        guard offset >= 0, offset <= size else {
            throw SpacesError.protocolError("lfs-get offset \(offset) out of range for \(oid) (\(size) bytes)")
        }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        try handle.seek(toOffset: UInt64(offset))
        let chunk = try handle.read(upToCount: LfsTransferOps.chunkSize) ?? Data()
        let complete = offset + Int64(chunk.count) >= size
        return ["v": RepositoryFormat.protocolVersion, "op": "lfs-get",
                "oid": oid, "offset": Int(offset), "size": Int(size),
                "data": chunk.base64EncodedString(), "complete": complete]
    }

    private func handleLfsPut(_ message: [String: Any]) throws -> [String: Any] {
        guard let oid = message["oid"] as? String, LfsLocalStore.isValidOID(oid) else {
            throw SpacesError.protocolError("lfs-put missing or invalid oid")
        }
        guard let total = Self.jsonInt(message["size"]), total >= 0,
              let offset = Self.jsonInt(message["offset"]), offset >= 0,
              let b64 = message["data"] as? String,
              let chunk = Data(base64Encoded: b64) else {
            throw SpacesError.protocolError("lfs-put missing fields")
        }
        let complete = message["complete"] as? Bool ?? false
        let partURL = LfsLocalStore.partURL(repo: repo, oid: oid)
        try FileManager.default.createDirectory(at: partURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        if offset == 0 {
            try? FileManager.default.removeItem(at: partURL)
            _ = FileManager.default.createFile(atPath: partURL.path, contents: Data())
        }
        guard let current = LfsLocalStore.fileSize(at: partURL), current == offset else {
            let have = LfsLocalStore.fileSize(at: partURL) ?? 0
            throw SpacesError.protocolError("lfs offset mismatch for \(oid): remote has \(have) bytes, got offset \(offset); restart from offset 0")
        }
        let handle = try FileHandle(forWritingTo: partURL)
        defer { try? handle.close() }
        _ = try handle.seekToEnd()
        try handle.write(contentsOf: chunk)
        try handle.synchronize()
        let stored = offset + Int64(chunk.count)
        if complete {
            guard stored == total else {
                try? FileManager.default.removeItem(at: partURL)
                throw SpacesError.lfsError("lfs object \(oid) incomplete: \(stored) of \(total) bytes")
            }
            guard try LfsLocalStore.verifyFile(at: partURL, oid: oid, size: total) else {
                try? FileManager.default.removeItem(at: partURL)
                throw SpacesError.lfsError("lfs object \(oid) failed hash verification")
            }
            let dest = LfsLocalStore.objectURL(repo: repo, oid: oid)
            try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.moveItem(at: partURL, to: dest)
        }
        return ["v": RepositoryFormat.protocolVersion, "op": "ok", "oid": oid, "stored": stored]
    }

    private func producePack(repo: Repository, wants: [String], haves: [String]) throws -> [[String: Any]] {
        var wantIDs: [ObjectID] = []
        for w in wants { if let o = try? ObjectID(validating: w) { wantIDs.append(o) } }
        var haveIDs: [ObjectID] = []
        for h in haves { if let o = try? ObjectID(validating: h) { haveIDs.append(o) } }

        let wantReach = try repo.objects.reachable(from: wantIDs)
        let haveReach = try repo.objects.reachable(from: haveIDs)
        let toSend = wantReach.subtracting(haveReach)

        var result: [[String: Any]] = []
        for id in toSend.sorted() {
            guard let stored = try? repo.objects.read(id) else { continue }
            result.append([
                "id": id.hex,
                "type": stored.type.rawValue,
                "data": stored.payload.base64EncodedString()
            ])
        }
        return result
    }
}
