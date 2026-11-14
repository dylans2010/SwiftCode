import Foundation












public enum DecompilerDatabaseSchema {
    
    
    public static let version = DecompilerCapabilities.databaseSchemaVersion

    

    public static let metaTable = "meta"
    public static let entitiesTable = "entities"

    
    public static let entitiesColumns = ["kind", "id", "payload"]

    
    public static let kindIndex = "idx_entities_kind"
    public static let idIndex = "idx_entities_id"

    

    
    
    
    public static func migrations() -> [String] {
        [
            
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

    
    public static let userVersionPragma = "PRAGMA user_version = \(version);"

    
    
    public enum EntityKind: String, Sendable, Codable, CaseIterable {
        case binary, function, symbol, string, xref, type
        case instruction, pseudocode, comment, label, finding, history
    }
}
