<!-- system-index-depends: CleanArchitectureSwift.md -->
# SQLite Storage Optimization & WAL Mode

Performance tuning, transaction management, and indexing strategies for embedded SQLite databases in Swift applications.

---

## 1. Essential PRAGMA Configurations
To maximize concurrency and write performance:
```sql
PRAGMA journal_mode = WAL;          -- Write-Ahead Logging allows concurrent readers and writer
PRAGMA synchronous = NORMAL;         -- Safely reduces disk flush overhead in WAL mode
PRAGMA foreign_keys = ON;            -- Enforces relational integrity
PRAGMA cache_size = -64000;          -- Allocates 64MB memory page cache
```

---

## 2. Batch Transactions
Never insert records in individual transactions inside a loop. Wrap inserts in explicit transactions:
```swift
func batchInsert(items: [RecordItem], db: OpaquePointer) throws {
    sqlite3_exec(db, "BEGIN TRANSACTION;", nil, nil, nil)
    defer {
        sqlite3_exec(db, "COMMIT;", nil, nil, nil)
    }
    // Execute prepared statements
}
```
