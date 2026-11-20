<!-- system-index-depends: Swift6Concurrency.md -->
# Core Data Concurrency & Thread Confinement

Concurrency patterns for maintaining database integrity, preventing faults, and managing `NSManagedObjectContext` in Core Data.

---

## 1. Thread Confinement Rule
`NSManagedObject` and `NSManagedObjectContext` instances are strictly confined to the thread/queue associated with their concurrency type.
- Never pass an `NSManagedObject` across threads.
- Pass `NSManagedObjectID` across boundaries and re-fetch on the target context.

---

## 2. Context Coordination Patterns
Always execute work on a context using `perform` or `performAndWait`:

```swift
final class CoreDataStack: Sendable {
    let persistentContainer: NSPersistentContainer

    func updateEntityInBackground(objectID: NSManagedObjectID, updateBlock: @escaping (ProjectMO) -> Void) async throws {
        let backgroundContext = persistentContainer.newBackgroundContext()
        try await backgroundContext.perform {
            guard let object = try? backgroundContext.existingObject(with: objectID) as? ProjectMO else {
                return
            }
            updateBlock(object)
            if backgroundContext.hasChanges {
                try backgroundContext.save()
            }
        }
    }
}
```
