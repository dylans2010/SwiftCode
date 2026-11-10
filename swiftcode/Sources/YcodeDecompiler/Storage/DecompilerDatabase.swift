import Foundation

/// Documentation-as-code for the SQLite backend of a `.scdecomp` project.
///
/// `AnalysisPersistence.SQLiteBackend` stores every entity kind as a JSON
/// payload in a single `entities` table plus a `meta` key/value table,
/// versioned through `PRAGMA user_version`. This enum records that schema
/// and the ordered migrations that produce it, so future schema revisions
/// have an explicit, reviewable history.
///
/// Entity `kind` values mirror the collections on `AnalysisStore`:
///   binary, function, symbol, string, xref, type, instruction,
///   pseudocode, comment, label, finding, history
public enum DecompilerDatabaseSchema {
    /// Current schema version. Must equal
    /// `DecompilerCapabilities.databaseSchemaVersion`.
    public static let version = DecompilerCapabilities.databaseSchemaVersion

    // MARK: - Table names

    public static let metaTable = "meta"
    public static let entitiesTable = "entities"

    /// Columns of `entities` (kind, id form the primary key).
    public static let entitiesColumns = ["kind", "id", "payload"]

    /// Index names created by the v1 migration.
    public static let kindIndex = "idx_entities_kind"
    public static let idIndex = "idx_entities_id"

    // MARK: - Migrations

    /// Ordered SQL migrations. `migrations()[i]` upgrades the database
    /// from schema version `i` to `i + 1`. Applying all of them must
    /// produce schema `version`.
    public static func migrations() -> [String] {
        [
            // v1: meta + entities store, JSON payloads, kind/id indexes.
            """
            CREATE TABLE IF NOT EXISTS meta (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS entities (
                kind TEXT NOT NULL,
                id TEXT NOT NULL,
                payload TEXT NOT NULL,
                PRIMARY KEY (kind, id)
            );

            CREATE INDEX IF NOT EXISTS idx_entities_kind ON entities(kind);
            CREATE INDEX IF NOT EXISTS idx_entities_id ON entities(id);

            INSERT OR REPLACE INTO meta(key, value)
                VALUES('schema_version', '\(version)');
            """
        ]
    }

    /// SQL that reports the schema version stored by the migration above.
    public static let userVersionPragma = "PRAGMA user_version = \(version);"

    /// Entity kinds persisted by `AnalysisPersistence`. Kept here so UI
    /// and export code can refer to the same vocabulary as the database.
    public enum EntityKind: String, Sendable, Codable, CaseIterable {
        case binary, function, symbol, string, xref, type
        case instruction, pseudocode, comment, label, finding, history
    }
}
