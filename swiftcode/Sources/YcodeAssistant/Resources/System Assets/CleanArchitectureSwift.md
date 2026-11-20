<!-- system-index-depends: SwiftUsage.md, MVVMAndStateManagement.md -->
# Clean Architecture & Layering for Apple Platforms

Architectural design principles for structuring robust, testable, and maintainable Swift codebases using Clean Architecture principles.

---

## 1. Layered Separation of Concerns
1. **Domain Layer (Core):**
   - Entities, Value Objects, Domain Errors, and Use Case Protocols.
   - Zero dependencies on frameworks (no SwiftUI, AppKit, CoreData, or Network frameworks).
   - Pure Swift business logic.
2. **Data / Infrastructure Layer:**
   - Repositories, Network Clients, Local Persistence (SwiftData/SQLite), Keychain.
   - Implements repository interfaces defined by the Domain Layer.
3. **Presentation Layer:**
   - SwiftUI Views, ViewModels, UI state models, Presenters.
   - Depends only on Domain Use Cases and entities.

```
+---------------------------------------------------------+
|                  Presentation Layer                     |
|         (SwiftUI Views, ViewModels, State)              |
+----------------------------+----------------------------+
                             | Calls Use Cases
                             v
+---------------------------------------------------------+
|                    Domain Layer                         |
|     (Entities, Use Cases, Repository Protocols)         |
+----------------------------^----------------------------+
                             | Implements Protocols
                             |
+----------------------------+----------------------------+
|                Data & Infrastructure                    |
|       (REST API, SwiftData, Keychain, File I/O)         |
+----------------------------+----------------------------+
```

---

## 2. Dependency Inversion Principle
High-level policy (Use Cases) must never depend on low-level detail (SQL, URLSession). Both depend on abstractions (Protocols).

```swift
public protocol ProjectRepository: Sendable {
    func loadProject(at path: String) async throws -> ProjectEntity
    func saveProject(_ project: ProjectEntity) async throws
}

public struct BuildProjectUseCase: Sendable {
    private let repository: any ProjectRepository
    
    public init(repository: any ProjectRepository) {
        self.repository = repository
    }
    
    public func execute(projectPath: String) async throws -> BuildResult {
        let project = try await repository.loadProject(at: projectPath)
        return project.compile()
    }
}
```

---

## 3. Boundary Crossing & DTOs
- Data Transfer Objects (DTOs) from JSON responses or database rows must be mapped to clean Domain Entities before reaching use cases.
- Never expose raw database entities (`NSManagedObject`, SwiftData schema models) to ViewModels or Views.

---

## 4. Assist Verification Checklist
- [ ] Are Domain protocols defined independently of concrete networking or database frameworks?
- [ ] Are dependencies injected via initializers rather than global singletons where testability is required?
- [ ] Are entities modeled as immutable Swift structs conforming to `Sendable`?
