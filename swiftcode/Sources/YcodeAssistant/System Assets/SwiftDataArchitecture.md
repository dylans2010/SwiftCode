<!-- system-index-depends: Swift6Concurrency.md, MVVMAndStateManagement.md -->
# SwiftData Architecture, Schema Design & ModelContext

Modern persistence architecture using Apple's SwiftData framework (`@Model`, `ModelContainer`, `ModelContext`).

---

## 1. Schema Modeling with `@Model`
```swift
import SwiftData

@Model
public final class ProjectEntity {
    @Attribute(.unique) public var identifier: String
    public var name: String
    public var path: String
    public var lastOpened: Date
    
    @Relationship(deleteRule: .cascade)
    public var files: [ProjectFileEntity] = []

    public init(identifier: String, name: String, path: String, lastOpened: Date = Date()) {
        self.identifier = identifier
        self.name = name
        self.path = path
        self.lastOpened = lastOpened
    }
}
```

---

## 2. Concurrency with `ModelContext`
- `ModelContext` is NOT thread-safe.
- Background persistence must use a dedicated background context created from `ModelContainer`.
- Use `ModelActor` to safely encapsulate SwiftData operations on a background concurrency domain:

```swift
@ModelActor
public actor BackgroundDatabaseWorker {
    public func insertProjects(_ dtos: [ProjectDTO]) throws {
        for dto in dtos {
            let entity = ProjectEntity(identifier: dto.id, name: dto.name, path: dto.path)
            modelContext.insert(entity)
        }
        try modelContext.save()
    }
}
```
