import AppKit
import SwiftUI
import YcodeIDECore

extension WorkspaceWindowController {
    @objc public func showSnippetsLibrary(_ sender: Any?) {
        guard window?.isVisible == true else { return }
        let controller = NSHostingController(rootView: SnippetsLibraryView(
            onInsert: { [weak self] snippet in
                self?.insertSnippetIntoEditor(snippet)
            },
            onSnippetsChanged: { [weak self] in
                self?.reloadSnippetsNavigator()
            }))
        let w = NSWindow(contentViewController: controller)
        w.title = "Snippets Library"
        w.setContentSize(NSSize(width: 920, height: 660))
        w.minSize = NSSize(width: 680, height: 480)
        w.center()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func insertSnippetIntoEditor(_ snippet: LibraryCodeSnippet) {
        var updated = snippet
        updated.usageCount += 1
        var all = LibraryCodeSnippetStore.load()
        if let i = all.firstIndex(where: { $0.id == snippet.id }) {
            all[i].usageCount = updated.usageCount
            LibraryCodeSnippetStore.save(all)
            reloadSnippetsNavigator()
        }
        var code = snippet.code
        if !code.hasSuffix("\n") { code += "\n" }
        editor.insertAtSelections(code)
    }

    func reloadSnippetsNavigator() {
        navigator.setSnippets(LibraryCodeSnippetStore.load())
    }
}
