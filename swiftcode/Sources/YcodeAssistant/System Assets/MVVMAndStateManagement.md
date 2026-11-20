<!-- system-index-depends: SwiftUIArchitecture.md, Swift6Concurrency.md -->
# MVVM & Modern State Management in Swift

Guidelines for implementing Model-View-ViewModel (MVVM) architectures using Swift 5.9+ Observation, unidirectional data flow, and error isolation.

---

## 1. The Observation Framework Paradigm
Modern SwiftUI applications use `@Observable` instead of the legacy `ObservableObject` / `@Published` pair.

### Benefits of `@Observable`:
- **Fine-Grained Invalidation:** Views re-evaluate body only when properties actually accessed in `body` change.
- **Zero Property Wrappers on Model:** Properties are declared as regular `var` variables without `@Published`.
- **Cleaner Concurrency:** Classes marked `@Observable` and `@MainActor` seamlessly interoperate with SwiftUI.

```swift
@Observable
@MainActor
public final class SourceEditorViewModel {
    public var documentText: String
    public var selectedRange: NSRange
    public var isSaving: Bool = false
    public var errorMessage: String?
    
    public init(documentText: String = "", selectedRange: NSRange = NSRange(location: 0, length: 0)) {
        self.documentText = documentText
        self.selectedRange = selectedRange
    }
    
    public func applyFormat() {
        // Business transformation
    }
}
```

---

## 2. Unidirectional Data Flow (UDF)
State flows down through Views; actions flow up to the ViewModel.
- **State:** Immutable snapshot of what the UI displays.
- **Intent / Action:** Explicit user gesture or system trigger dispatched to the ViewModel.
- **Mutation:** ViewModel executes business logic, mutates state on `@MainActor`, and notifies views.

---

## 3. Handling Transient Events & Alerts
Model transient alerts and navigation states using optional enum state machines rather than detached booleans:

```swift
public enum EditorSheetState: Identifiable {
    case findAndReplace
    case documentSettings(String)
    case exportOptions
    
    public var id: String {
        switch self {
        case .findAndReplace: return "find"
        case .documentSettings(let id): return "doc_\(id)"
        case .exportOptions: return "export"
        }
    }
}
```

---

## 4. Assist Operational Guidelines
- Eliminate Combine boilerplate (`AnyCancellable`, `objectWillChange.send()`) in favor of `@Observable`.
- Ensure ViewModels do not import UI frameworks (AppKit/UIKit) unless platform-specific types (e.g. `NSColor`) are strictly necessary.
