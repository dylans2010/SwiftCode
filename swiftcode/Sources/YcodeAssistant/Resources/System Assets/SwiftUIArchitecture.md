<!-- system-index-depends: SwiftUsage.md, MVVMAndStateManagement.md -->
# SwiftUI Architecture & Component Design

Technical guidelines and architectural standards for developing robust, scalable, and high-performance SwiftUI applications across macOS and Apple platforms.

---

## 1. Core Principles of Declarative UI
- **Single Source of Truth:** Every piece of mutable state must have a single authoritative owner. Child views project state via bindings or observe shared domain models.
- **View as a Pure Projection of State:** A SwiftUI View body must be an idempotent function of its state and environment. Never trigger side effects directly within `body`.
- **Structural Identity vs Explicit Identity:** Prefer structural identity established by SwiftUI view hierarchy and `@ViewBuilder` over manual explicit identifiers (`id()`), unless animating dynamic lists.

---

## 2. State Management Hierarchy
1. `@State`: Private, transient view-local state. Primitive values, toggle states, animation triggers. Never pass `@State` downstream when domain models are required.
2. `@Binding`: Two-way reference to state owned by an ancestor view. Allows child components to mutate parent state without owning the storage.
3. `@Observable` (Observation Framework): The standard for reference-type view models and domain state in modern Swift. Replaces `ObservableObject` and `@Published`.
4. `@Environment`: Dependency injection container for system values (colorScheme, scenePhase, dismiss) and custom domain dependencies injected via `.environment(model)`.

```swift
@Observable
@MainActor
final class ProjectNavigatorViewModel {
    var searchQuery: String = ""
    var isFiltering: Bool = false
    private(set) var items: [ProjectItem] = []
    
    func performSearch() {
        // Business logic isolated to model
    }
}

struct ProjectNavigatorView: View {
    @State private var viewModel = ProjectNavigatorViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List(viewModel.items) { item in
                ProjectItemRow(item: item)
            }
            .searchable(text: $viewModel.searchQuery)
        }
    }
}
```

---

## 3. View Composition & Extraction Best Practices
- **Granular Decomposition:** Break complex views down into small, focused subviews. SwiftUI view struct instantiation is lightweight; small views optimize diffing and invalidation scopes.
- **ViewModifier Encapsulation:** Encapsulate recurring style patterns, transitions, and layout constraints into reusable `ViewModifier` structs with companion `View` extensions.
- **Custom Container Views:** Use `@ViewBuilder` to create layout primitives with flexible content slots.

---

## 4. Performance Pitfalls & Anti-Patterns
- **Heavy Computations in Body:** Never instantiate formatters, parse JSON, or execute disk I/O in `body`. Precompute or cache on models.
- **Accidental Body Dependency Invalidation:** Avoid observing entire giant god-objects when only one boolean property is needed in the subview.
- **Misusing AnyView:** Avoid `AnyView` type erasure. It destroys structural identity and breaks state preservation during re-renders. Use `@ViewBuilder` or `Group` instead.

---

## 5. Assist Verification Checklist
- [ ] Are all state mutations dispatched on `@MainActor`?
- [ ] Is domain logic isolated to `@Observable` classes rather than view structs?
- [ ] Are views cleanly broken down without bloated bodies exceeding 80 lines?
- [ ] Is `AnyView` eliminated in favor of `@ViewBuilder`?
