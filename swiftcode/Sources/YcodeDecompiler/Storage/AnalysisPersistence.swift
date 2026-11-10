import Foundation
#if canImport(CSQLite)
import CSQLite
#endif

/// Persists analysis results into a `.scdecomp` project.
/// Uses SQLite when the CSQLite module is available (SwiftPM builds);
/// otherwise a JSON snapshot (xcodeproj builds) — same data either way.
public enum AnalysisPersistence {
    public static func save(store: AnalysisStore, project: DecompilerProject,
                            image: BinaryImage?) async throws {
        #if canImport(CSQLite)
        try await SQLiteBackend.save(store: store, project: project, image: image)
        #else
        try await JSONBackend.save(store: store, project: project, image: image)
        #endif
    }

    public static func load(project: DecompilerProject) async throws -> AnalysisStore {
        #if canImport(CSQLite)
        if FileManager.default.fileExists(atPath: project.databaseURL.path) {
            return try await SQLiteBackend.load(project: project)
        }
        #endif
        if FileManager.default.fileExists(atPath: project.jsonStoreURL.path) {
            return try await JSONBackend.load(project: project)
        }
        return AnalysisStore()
    }
}

/// Codable snapshot of everything the store persists.
struct AnalysisSnapshot: Codable {
    var schemaVersion: Int = DecompilerCapabilities.databaseSchemaVersion
    /// Identity of the analyzed binary (content hash); the image itself is
    /// re-imported on project open, not serialized.
    var binaryIdentity: BinaryIdentity?
    var functions: [DecompilerFunction]
    var symbols: [BinarySymbol]
    var strings: [BinaryString]
    var crossReferences: [CrossReference]
    var types: [TypeInfo]
    var comments: [String: String]
    var userLabels: [String: String]
    var findings: [AnalysisFinding]
    var history: [AnalysisHistoryEntry]
    var pseudocode: [String: DecompilationResult]  // keyed by address hex
    var savedAt: Date
}

enum JSONBackend {
    static func snapshot(store: AnalysisStore, image: BinaryImage?) async -> AnalysisSnapshot {
        let pseudocodeMap = await store.pseudocode.reduce(into: [String: DecompilationResult]()) {
            $0[String($1.key, radix: 16)] = $1.value
        }
        return AnalysisSnapshot(
            binaryIdentity: image?.identity,
            functions: await store.functions,
            symbols: await store.symbols,
            strings: await store.stringsList,
            crossReferences: await store.crossReferences,
            types: await store.types,
            comments: await store.comments,
            userLabels: await store.userLabels,
            findings: await store.findings,
            history: await store.history,
            pseudocode: pseudocodeMap,
            savedAt: Date())
    }

    static func save(store: AnalysisStore, project: DecompilerProject,
                     image: BinaryImage?) async throws {
        let snap = await snapshot(store: store, image: image)
        let data = try JSONEncoder.decompiler.encode(snap)
        try data.write(to: project.jsonStoreURL, options: .atomic)
    }

    static func load(project: DecompilerProject) async throws -> AnalysisStore {
        let data = try Data(contentsOf: project.jsonStoreURL)
        let snap = try JSONDecoder.decompiler.decode(AnalysisSnapshot.self, from: data)
        return await hydrate(snap)
    }

    static func hydrate(_ snap: AnalysisSnapshot) async -> AnalysisStore {
        let store = AnalysisStore()
        await store.upsertFunctions(snap.functions)
        await store.upsertSymbols(snap.symbols)
        await store.setStrings(snap.strings)
        await store.addCrossReferences(snap.crossReferences)
        await store.upsertTypes(snap.types)
        for (k, v) in snap.comments {
            if let a = DecompilerAddress.parse(k) { await store.setComment(v, at: a) }
        }
        for (k, v) in snap.userLabels {
            if let a = DecompilerAddress.parse(k) { await store.setUserLabel(v, at: a) }
        }
        for f in snap.findings { await store.addFinding(f) }
        for h in snap.history { await store.recordHistory(h) }
        for (_, r) in snap.pseudocode { await store.storePseudocode(r) }
        return store
    }
}

#if canImport(CSQLite)
enum SQLiteBackend {
    /// Minimal SQLite persistence: one table per entity kind, JSON payloads.
    /// Versioned via PRAGMA user_version = databaseSchemaVersion.
    static func save(store: AnalysisStore, project: DecompilerProject,
                     image: BinaryImage?) async throws {
        let snap = await JSONBackend.snapshot(store: store, image: image)
        var db: OpaquePointer?
        guard sqlite3_open_v2(project.databaseURL.path, &db,
                              SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX,
                              nil) == SQLITE_OK, let db else {
            throw DecompilerError.persistenceFailure("cannot open Analysis.sqlite")
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 5000)
        try exec(db, """
            CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT);
            CREATE TABLE IF NOT EXISTS entities (kind TEXT NOT NULL, id TEXT NOT NULL, payload TEXT NOT NULL,
                                                 PRIMARY KEY (kind, id));
            PRAGMA user_version = \(DecompilerCapabilities.databaseSchemaVersion);
            """)
        try exec(db, "DELETE FROM entities")
        try exec(db, "DELETE FROM meta")

        func insert(_ kind: String, _ id: String, _ payload: String) throws {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, "INSERT INTO entities(kind,id,payload) VALUES(?,?,?)",
                                     -1, &stmt, nil) == SQLITE_OK else {
                throw sqlite3Error(db, "prepare")
            }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, kind, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(stmt, 2, id, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(stmt, 3, payload, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            guard sqlite3_step(stmt) == SQLITE_DONE else { throw sqlite3Error(db, "insert \(kind)") }
        }

        let encoder = JSONEncoder.decompiler
        func payload<T: Encodable>(_ v: T) throws -> String {
            String(decoding: try encoder.encode(v), as: UTF8.self)
        }

        for f in snap.functions { try insert("function", f.id, try payload(f)) }
        for s in snap.symbols { try insert("symbol", s.id, try payload(s)) }
        for s in snap.strings { try insert("string", "\(s.address.hexString)-\(s.fileOffset)", try payload(s)) }
        for x in snap.crossReferences { try insert("xref", x.id, try payload(x)) }
        for t in snap.types { try insert("type", t.id, try payload(t)) }
        for f in snap.findings { try insert("finding", f.id, try payload(f)) }
        for h in snap.history { try insert("history", h.id, try payload(h)) }
        for (k, r) in snap.pseudocode { try insert("pseudocode", k, try payload(r)) }
        for (k, v) in snap.comments { try insert("comment", k, payloadJSONString(v)) }
        for (k, v) in snap.userLabels { try insert("label", k, payloadJSONString(v)) }
        if let b = snap.binaryIdentity { try insert("binary", b.stableID, try payload(b)) }

        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, "INSERT INTO meta(key,value) VALUES('snapshot',?)", -1, &stmt, nil)
        defer { sqlite3_finalize(stmt) }
        let meta = try payload(snap)
        sqlite3_bind_text(stmt, 1, meta, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        _ = sqlite3_step(stmt)
    }

    static func load(project: DecompilerProject) async throws -> AnalysisStore {
        var db: OpaquePointer?
        guard sqlite3_open_v2(project.databaseURL.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let db else { throw DecompilerError.persistenceFailure("cannot open Analysis.sqlite") }
        defer { sqlite3_close(db) }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT payload FROM entities WHERE kind='snapshot' LIMIT 1", -1, &stmt, nil) == SQLITE_OK else {
            throw sqlite3Error(db, "prepare")
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW,
              let c = sqlite3_column_text(stmt, 0) else {
            return AnalysisStore()
        }
        let snap = try JSONDecoder.decompiler.decode(AnalysisSnapshot.self,
            from: Data(String(cString: c).utf8))
        return await JSONBackend.hydrate(snap)
    }

    private static func payloadJSONString(_ s: String) throws -> String {
        String(decoding: try JSONEncoder.decompiler.encode(s), as: UTF8.self)
    }

    private static func exec(_ db: OpaquePointer, _ sql: String) throws {
        var err: UnsafeMutablePointer<Int8>?
        guard sqlite3_exec(db, sql, nil, nil, &err) == SQLITE_OK else {
            let m = err.map { String(cString: $0) } ?? "sqlite error"
            sqlite3_free(err)
            throw DecompilerError.persistenceFailure(m)
        }
    }

    private static func sqlite3Error(_ db: OpaquePointer, _ what: String) -> DecompilerError {
        .persistenceFailure("\(what): \(String(cString: sqlite3_errmsg(db)))")
    }
}
#endif
