import AppKit
import Foundation

extension WorkspaceWindowController {
    @objc public func showDevTools(_ sender: Any?) {
        NotificationCenter.default.post(name: Notification.Name("com.swiftcode.showDevTools"), object: nil)
        let folder = session.model.url.hasDirectoryPath ? session.model.url : session.model.projects.keys.first.map(URL.init(fileURLWithPath:)) ?? session.model.url.deletingLastPathComponent()
        SCToolsWindowManager.shared.showWindow(workspaceFolder: folder)
    }
}
