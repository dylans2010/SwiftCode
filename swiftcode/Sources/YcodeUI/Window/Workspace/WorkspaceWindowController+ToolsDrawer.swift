import AppKit
import YcodeIDECore

extension WorkspaceWindowController {
    @objc public func toggleToolsDrawer(_ sender: Any?) {
        let folder = session.model.url.hasDirectoryPath ? session.model.url : session.model.projects.keys.first.map(URL.init(fileURLWithPath:)) ?? session.model.url.deletingLastPathComponent()
        SCToolsWindowManager.shared.toggle(workspaceFolder: folder)
    }
}
