<!-- system-index-depends: CleanArchitectureSwift.md -->
# CloudKit Synchronization Architecture & Conflict Resolution

Best practices for syncing application data to iCloud using CloudKit (`CKDatabase`, `CKSyncEngine`, `CKRecordZone`).

---

## 1. Modern Sync with `CKSyncEngine`
Apple's `CKSyncEngine` handles change tracking, batch scheduling, network state monitoring, and retry logic automatically.
- Store server change tokens to fetch incremental changes.
- Sync only differential updates rather than complete database dumps.

---

## 2. Conflict Resolution Strategies
- **Server Record Wins:** Safest for read-heavy system assets.
- **Client Record Wins:** Used when local user actions supersede stale cloud state.
- **Three-Way Merge:** Field-by-field merge using a common ancestor timestamp.
