import AppKit

final class TerminalPanelHolder {
    var controller: TerminalPanelController?
    var restoreHeight: CGFloat?
    var observer: NSObjectProtocol?
    static let heightKey = "SwiftCodeTerminalPanelHeight"
    static let defaultHeight: CGFloat = 260
    static let minimumHeight: CGFloat = 120

    var savedHeight: CGFloat {
        get {
            let h = UserDefaults.standard.double(forKey: Self.heightKey)
            return h >= Double(Self.minimumHeight) ? CGFloat(h) : Self.defaultHeight
        }
        set { UserDefaults.standard.set(Double(newValue), forKey: Self.heightKey) }
    }
}

@MainActor
public enum IntegratedTerminal {
    static var frontWorkspace: WorkspaceWindowController? {
        for window in [NSApp.keyWindow, NSApp.mainWindow] + NSApp.orderedWindows.map(Optional.some) {
            if let wc = window?.windowController as? WorkspaceWindowController, window?.isVisible == true { return wc }
        }
        return nil
    }

    public static func toggle(fallbackFolder: URL?) {
        if let wc = frontWorkspace { wc.toggleTerminalPanel(nil) } else { TerminalWindowManager.shared.showWindow(workspaceFolder: fallbackFolder) }
    }

    public static func show(fallbackFolder: URL?) {
        if let wc = frontWorkspace {
            wc.window?.makeKeyAndOrderFront(nil)
            wc.showTerminalPanel(true)
        } else {
            TerminalWindowManager.shared.showWindow(workspaceFolder: fallbackFolder)
        }
    }

    public static func showAtCurrentLocation(fallbackFolder: URL?) {
        guard let wc = frontWorkspace else { return TerminalWindowManager.shared.showWindow(workspaceFolder: fallbackFolder) }
        let directory = wc.editor.fileURL?.deletingLastPathComponent().path ?? wc.workspaceFolder.path
        wc.showTerminalPanel(true)
        if wc.terminalPanel.activeSession?.workingDirectory != directory { wc.terminalPanel.changeDirectory(to: directory) }
    }
}

extension WorkspaceWindowController {
    public var terminalPanel: TerminalPanelController {
        if let c = terminalHolder.controller { return c }
        let c = TerminalPanelController(workspaceFolder: workspaceFolder)
        c.startsAutomatically = false
        c.onClose = { [weak self] in self?.showTerminalPanel(false) }
        c.onToggleMaximize = { [weak self] in self?.toggleTerminalPanelMaximized() }
        c.onOpenPath = { [weak self] path, line in
            guard let self else { return false }
            self.open(path: path, line: line)
            return true
        }
        terminalHolder.controller = c
        return c
    }

    func installTerminalPanel() {
        terminalItem = NSSplitViewItem(viewController: terminalPanel)
        terminalItem.canCollapse = true
        terminalItem.minimumThickness = TerminalPanelHolder.minimumHeight
        terminalItem.isCollapsed = true
        terminalItem.holdingPriority = NSLayoutConstraint.Priority(rawValue: 261)
        centerSplit.addSplitViewItem(terminalItem)
        terminalHolder.observer = NotificationCenter.default.addObserver(forName: NSSplitView.didResizeSubviewsNotification,
                                                                         object: centerSplit.splitView, queue: .main) { [weak self] n in
            guard n.userInfo?["NSSplitViewDividerIndex"] != nil else { return }
            Task { @MainActor in
                guard let self, !self.terminalItem.isCollapsed, self.terminalHolder.restoreHeight == nil else { return }
                let h = self.terminalPanel.view.frame.height
                if h >= TerminalPanelHolder.minimumHeight { self.terminalHolder.savedHeight = h }
            }
        }
    }

    public var isTerminalPanelShown: Bool { !terminalItem.isCollapsed }

    var terminalPanelOccupiedHeight: CGFloat {
        terminalItem.isCollapsed ? 0 : terminalPanel.view.frame.height + centerSplit.splitView.dividerThickness
    }

    @objc public func toggleTerminalPanel(_ sender: Any?) {
        if isTerminalPanelShown, window?.firstResponder !== terminalPanel.activeSession?.view {
            terminalPanel.focus()
        } else {
            showTerminalPanel(!isTerminalPanelShown)
        }
    }

    private func setTerminalPanelHeight(_ height: CGFloat) {
        let split = centerSplit.splitView
        centerSplit.view.layoutSubtreeIfNeeded()
        let available = split.bounds.height - 80 - (debugItem.isCollapsed ? 0 : debugArea.view.frame.height + split.dividerThickness)
        let h = max(TerminalPanelHolder.minimumHeight, min(height, available))
        split.setPosition(split.bounds.height - h - split.dividerThickness, ofDividerAt: 1)
        centerSplit.view.layoutSubtreeIfNeeded()
    }

    public func showTerminalPanel(_ show: Bool) {
        let panel = terminalPanel
        guard terminalItem.isCollapsed == show else {
            if show { panel.focus() }
            return
        }
        if show {
            let height = terminalHolder.savedHeight
            panel.view.setFrameSize(NSSize(width: panel.view.frame.width, height: height))
            terminalItem.isCollapsed = false
            setTerminalPanelHeight(height)
            panel.ensureSession()
            panel.focus()
        } else {
            terminalHolder.restoreHeight = nil
            terminalItem.isCollapsed = true
            window?.makeFirstResponder(editor.textView)
        }
    }

    func toggleTerminalPanelMaximized() {
        guard isTerminalPanelShown else { return }
        if let restore = terminalHolder.restoreHeight {
            setTerminalPanelHeight(restore)
            terminalHolder.restoreHeight = nil
        } else {
            terminalHolder.restoreHeight = terminalPanel.view.frame.height
            setTerminalPanelHeight(.greatestFiniteMagnitude)
        }
    }

    public func runInTerminal(_ command: String) {
        showTerminalPanel(true)
        terminalPanel.run(command)
    }
}
