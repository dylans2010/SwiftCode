<!-- system-index-depends: SwiftUIArchitecture.md -->
# App Lifecycle, Scene Management & Document Architecture

Technical reference for configuring modern SwiftUI App life cycles, multi-window scenes, document-based apps, and system lifecycle events.

---

## 1. The `@main` App Primitive
In modern SwiftUI, an application is declared using the `@main` attribute on a struct conforming to `App`.

```swift
@main
struct SwiftCodeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var workspaceState = WorkspaceStateManager()
    
    var body: some Scene {
        WindowGroup {
            WorkspaceContainerView()
                .environment(workspaceState)
        }
        .commands {
            SidebarCommands()
            ToolbarCommands()
            ProjectCommandMenu()
        }
        
        Settings {
            PreferencesRootView()
        }
    }
}
```

---

## 2. Multi-Window & Scene Phase Handling
- **`WindowGroup`:** Supports creating multiple independent windows for workspaces.
- **`@Environment(\.scenePhase)`:** Tracks scene lifecycle:
  - `.active`: Window is in foreground and interactive.
  - `.inactive`: Window is temporarily in background or losing focus.
  - `.background`: Window or app is completely hidden; suspend heavy polling or save state immediately.

---

## 3. Document-Based Scenes (`DocumentGroup`)
For document-centric editors handling custom file formats (e.g., project workspaces, canvas documents):

```swift
struct SwiftCodeDocumentApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: ProjectWorkspaceDocument()) { file in
            WorkspaceEditorView(document: file.$document)
        }
    }
}
```

---

## 4. AppKit Integration via `NSApplicationDelegateAdaptor`
When native macOS lifecycle hooks are required (dock menu customization, URL handling, terminating validation):
- Implement an `NSObject` conforming to `NSApplicationDelegate`.
- Bind to the SwiftUI app via `@NSApplicationDelegateAdaptor`.

---

## 5. Assist Operational Guidelines
- Never invoke `exit()` directly; use `NSApplication.shared.terminate(nil)` to ensure clean state saving.
- Register background tasks and flush unsaved caches during `.background` phase transitions.
