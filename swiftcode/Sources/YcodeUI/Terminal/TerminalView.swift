import AppKit
import SwiftUI

public struct TerminalView: NSViewControllerRepresentable {
    private let workspaceFolder: URL?

    public init(workspaceFolder: URL? = nil) {
        self.workspaceFolder = workspaceFolder
    }

    public func makeNSViewController(context: Context) -> TerminalPanelController {
        let controller = TerminalPanelController(workspaceFolder: workspaceFolder)
        controller.showsPanelControls = false
        return controller
    }

    public func updateNSViewController(_ controller: TerminalPanelController, context: Context) {}

    public static func dismantleNSViewController(_ controller: TerminalPanelController, coordinator: ()) {
        controller.shutdown()
    }
}
