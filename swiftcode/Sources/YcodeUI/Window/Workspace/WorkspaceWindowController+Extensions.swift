import AppKit
import SwiftUI
import YcodeIDECore

final class ExtensionsPanelHolder: NSObject, NSPopoverDelegate {
    var controller: ExtensionsPanelViewController?
    var popover: NSPopover?

    func popoverDidClose(_ notification: Notification) {
        MainActor.assumeIsolated {
            controller = nil
            popover = nil
        }
    }
}

extension WorkspaceWindowController {
    public var extensionsPanel: ExtensionsPanelViewController? { extensionsPanelHolder.controller }

    @objc public func toggleExtensionsPanel(_ sender: Any?) {
        if let p = extensionsPanelHolder.popover { p.close(); return }
        let c = ExtensionsPanelViewController()
        _ = c.view
        c.runExtensionHandler = { [weak self] id in
            self?.presentExtensionRun(extensionId: id)
        }
        extensionsPanelHolder.controller = c
        guard window?.isVisible == true else { return }
        let p = NSPopover()
        p.contentViewController = c
        p.contentSize = ExtensionsPanelViewController.size
        p.behavior = .transient
        p.delegate = extensionsPanelHolder
        extensionsPanelHolder.popover = p
        if let item = window?.toolbar?.items.first(where: { $0.itemIdentifier == Self.extensionsID }),
           let view = item.view, let window = window {
            p.show(relativeTo: view.bounds, of: view, preferredEdge: .maxY)
        } else if let contentView = window?.contentView {
            let anchor = NSRect(x: contentView.bounds.maxX - 320, y: contentView.bounds.maxY - 10, width: 1, height: 1)
            p.show(relativeTo: anchor, of: contentView, preferredEdge: .maxY)
        }
    }

    
    
    @objc public func showExtensions(_ sender: Any?) {
        ExtensionsWindowManager.shared.show()
    }

    
    
    public func presentExtensionRun(extensionId: String) {
        let host = NSHostingController(rootView: ExtensionRunView(extensionId: extensionId))
        if let presenter = contentViewController, window?.isVisible == true {
            presenter.presentAsSheet(host)
        } else {
            ExtensionsWindowManager.shared.show()
        }
    }
}
