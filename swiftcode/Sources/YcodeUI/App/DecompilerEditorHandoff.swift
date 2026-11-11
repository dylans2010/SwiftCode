import AppKit
import YcodeDecompiler
import YcodeIDECore

@MainActor final class IDEEditorHandoff: DecompilerEditorHandoff {
    private var windowControllers: [WorkspaceWindowController] = []

    @MainActor func openProject(at url: URL) async throws {
        if let existing = windowControllers.first(where: {
            $0.session.model.url.standardizedFileURL == url.standardizedFileURL
        }) {
            existing.showWindow(nil)
            existing.window?.makeKeyAndOrderFront(nil)
            return
        }
        let session = try await ProjectOpeningCoordinator.shared.open(url)
        let controller = WorkspaceWindowController(session: session)
        windowControllers.append(controller)
        controller.showWindow(nil)
        controller.window?.center()
        controller.window?.makeKeyAndOrderFront(nil)
        controller.applyDefaultLayout()
        controller.openFirstSourceFile()
    }

    @MainActor func openFile(at url: URL, line: Int?) async {
        if let controller = windowControllers.first(where: {
            url.path.hasPrefix($0.session.model.url.path)
        }) {
            controller.showWindow(nil)
            controller.window?.makeKeyAndOrderFront(nil)
            controller.open(path: url.path, line: line)
            return
        }
        var candidate: URL? = url.deletingLastPathComponent()
        while let dir = candidate {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) {
                do {
                    try await openProject(at: dir)
                    await openFile(at: url, line: line)
                } catch {}
                return
            }
            candidate = dir.deletingLastPathComponent() == dir ? nil : dir.deletingLastPathComponent()
        }
    }
}
