import SwiftUI
import AppKit


public enum DecompilerToolbarItem: String {
    case modePicker = "decompiler.modePicker"
    case analyze = "decompiler.analyze"
    case cancelAnalysis = "decompiler.cancelAnalysis"
    case importBinary = "decompiler.importBinary"
    case saveProject = "decompiler.saveProject"
    case assistToggle = "decompiler.assistToggle"
    case inspectorToggle = "decompiler.inspectorToggle"
    case consoleToggle = "decompiler.consoleToggle"
    case search = "decompiler.search"
    case goToAddress = "decompiler.goToAddress"
    case goToFunction = "decompiler.goToFunction"
    case exportAnalysis = "decompiler.exportAnalysis"
    case restoreLayout = "decompiler.restoreLayout"
    case decompileAsset = "decompiler.decompileAsset"
    case assemble = "decompiler.assemble"
    case backendPicker = "decompiler.backendPicker"
    case openInMainEditor = "decompiler.openInMainEditor"
}



@MainActor
public final class DecompilerWindowController: NSWindowController, NSToolbarDelegate {
    public let state: DecompilerObservableState
    private weak var backendPicker: NSPopUpButton?

    public init(state: DecompilerObservableState) {
        self.state = state

        let window = NSWindow(
            contentRect: NSRect(x: 200, y: 120, width: 1400, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        let sessionID = state.session.id
        window.title = "Decompiler — \(sessionID.uuidString.prefix(8))"
        window.minSize = NSSize(width: 900, height: 600)
        window.setFrameAutosaveName("DecompilerMainWindow")
        window.collectionBehavior = [.fullScreenPrimary, .managed]
        window.isReleasedWhenClosed = false
        window.identifier = NSUserInterfaceItemIdentifier("decompiler.window.\(sessionID.uuidString)")

        super.init(window: window)

        let root = DecompilerRootView(state: state)
        window.contentViewController = NSHostingController(rootView: root)

        let toolbar = NSToolbar(identifier: "DecompilerToolbar")
        toolbar.delegate = self
        toolbar.allowsUserCustomization = true
        toolbar.autosavesConfiguration = true
        toolbar.displayMode = .iconAndLabel
        window.toolbar = toolbar

        
        Task { [weak window] in
            await state.refresh()
            await MainActor.run {
                if let name = state.binary?.identity.originalFileName {
                    window?.title = "\(name) — Decompiler"
                }
            }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    

    public func toolbar(_ toolbar: NSToolbar,
                        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                        willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard let item = DecompilerToolbarItem(rawValue: itemIdentifier.rawValue) else {
            return nil
        }
        let toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)

        switch item {
        case .modePicker:
            let seg = NSSegmentedControl(
                labels: ["Friendly", "Master"],
                trackingMode: .selectOne,
                target: self,
                action: #selector(modeChanged(_:))
            )
            seg.selectedSegment = state.mode == .friendly ? 0 : 1
            seg.controlSize = .small
            seg.setAccessibilityLabel("Workspace mode")
            toolbarItem.view = seg
            toolbarItem.label = "Mode"
            toolbarItem.paletteLabel = "Workspace Mode"
            return toolbarItem

        case .analyze:
            toolbarItem.label = "Analyze"
            toolbarItem.paletteLabel = "Analyze"
            toolbarItem.toolTip = "Run the static analysis pipeline"
            toolbarItem.image = NSImage(systemSymbolName: "play.circle", accessibilityDescription: nil)
            toolbarItem.target = self
            toolbarItem.action = #selector(analyzeAction(_:))
            return toolbarItem

        case .cancelAnalysis:
            toolbarItem.label = "Cancel"
            toolbarItem.paletteLabel = "Cancel Analysis"
            toolbarItem.toolTip = "Cancel the running analysis"
            toolbarItem.image = NSImage(systemSymbolName: "stop.circle", accessibilityDescription: nil)
            toolbarItem.target = self
            toolbarItem.action = #selector(cancelAnalysisAction(_:))
            return toolbarItem

        case .importBinary:
            toolbarItem.label = "Import Binary"
            toolbarItem.paletteLabel = "Import Binary"
            toolbarItem.toolTip = "Import a Mach-O, ELF, or PE binary"
            toolbarItem.image = NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: nil)
            toolbarItem.target = self
            toolbarItem.action = #selector(importBinaryAction(_:))
            return toolbarItem

        case .saveProject:
            toolbarItem.label = "Save Project"
            toolbarItem.paletteLabel = "Save Project"
            toolbarItem.toolTip = "Save analysis into a .scdecomp project"
            toolbarItem.image = NSImage(systemSymbolName: "square.and.arrow.down", accessibilityDescription: nil)
            toolbarItem.target = self
            toolbarItem.action = #selector(saveProjectAction(_:))
            return toolbarItem

        case .assistToggle:
            toolbarItem.label = "Assist"
            toolbarItem.paletteLabel = "Decompile Assist"
            toolbarItem.toolTip = "Toggle the Decompile Assist panel"
            toolbarItem.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)
            toolbarItem.target = self
            toolbarItem.action = #selector(assistToggleAction(_:))
            return toolbarItem

        case .inspectorToggle:
            toolbarItem.label = "Inspector"
            toolbarItem.paletteLabel = "Toggle Inspector"
            toolbarItem.toolTip = "Toggle the inspector pane"
            toolbarItem.image = NSImage(systemSymbolName: "sidebar.right", accessibilityDescription: nil)
            toolbarItem.target = self
            toolbarItem.action = #selector(inspectorToggleAction(_:))
            return toolbarItem

        case .consoleToggle:
            toolbarItem.label = "Console"
            toolbarItem.paletteLabel = "Toggle Console"
            toolbarItem.toolTip = "Toggle the analysis console"
            toolbarItem.image = NSImage(systemSymbolName: "text.alignleft", accessibilityDescription: nil)
            toolbarItem.target = self
            toolbarItem.action = #selector(consoleToggleAction(_:))
            return toolbarItem

        case .search:
            toolbarItem.label = "Search"
            toolbarItem.paletteLabel = "Search"
            toolbarItem.toolTip = "Search the current list"
            toolbarItem.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)
            toolbarItem.target = self
            toolbarItem.action = #selector(searchAction(_:))
            return toolbarItem

        case .goToAddress:
            toolbarItem.label = "Go to Address"
            toolbarItem.paletteLabel = "Go to Address"
            toolbarItem.toolTip = "Navigate to a virtual address"
            toolbarItem.image = NSImage(systemSymbolName: "number", accessibilityDescription: nil)
            toolbarItem.target = self
            toolbarItem.action = #selector(goToAddressAction(_:))
            return toolbarItem

        case .goToFunction:
            toolbarItem.label = "Go to Function"
            toolbarItem.paletteLabel = "Go to Function"
            toolbarItem.toolTip = "Jump to a function by name"
            toolbarItem.image = NSImage(systemSymbolName: "function", accessibilityDescription: nil)
            toolbarItem.target = self
            toolbarItem.action = #selector(goToFunctionAction(_:))
            return toolbarItem

        case .exportAnalysis:
            toolbarItem.label = "Export"
            toolbarItem.paletteLabel = "Export Analysis"
            toolbarItem.toolTip = "Export pseudocode, disassembly, and strings to a text report"
            toolbarItem.image = NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: nil)
            toolbarItem.target = self
            toolbarItem.action = #selector(exportAction(_:))
            return toolbarItem

        case .restoreLayout:
            toolbarItem.label = "Restore Layout"
            toolbarItem.paletteLabel = "Restore Layout"
            toolbarItem.toolTip = "Restore default pane layout"
            toolbarItem.image = NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: nil)
            toolbarItem.target = self
            toolbarItem.action = #selector(restoreLayoutAction(_:))
            return toolbarItem

        case .decompileAsset:
            toolbarItem.label = "Decompile Asset"
            toolbarItem.paletteLabel = "Decompile Asset"
            toolbarItem.toolTip = "Decompile every function and generate the editable source project"
            toolbarItem.image = NSImage(systemSymbolName: "arrow.down.doc", accessibilityDescription: nil)
            toolbarItem.target = self
            toolbarItem.action = #selector(decompileAssetAction(_:))
            return toolbarItem

        case .assemble:
            toolbarItem.label = "Assemble"
            toolbarItem.paletteLabel = "Assemble"
            toolbarItem.toolTip = "Compile and link the reconstructed project into a new dynamic library"
            toolbarItem.image = NSImage(systemSymbolName: "hammer", accessibilityDescription: nil)
            toolbarItem.target = self
            toolbarItem.action = #selector(assembleAction(_:))
            return toolbarItem

        case .backendPicker:
            let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 170, height: 24), pullsDown: false)
            popup.autoenablesItems = false
            popup.controlSize = .small
            populateBackendPicker(popup)
            popup.menu?.delegate = self
            popup.target = self
            popup.action = #selector(backendChanged(_:))
            popup.setAccessibilityLabel("Assemble backend")
            backendPicker = popup
            toolbarItem.view = popup
            toolbarItem.label = "Backend"
            toolbarItem.paletteLabel = "Assemble Backend"
            toolbarItem.toolTip = "Choose the Assemble backend"
            return toolbarItem

        case .openInMainEditor:
            toolbarItem.label = "Open in Editor"
            toolbarItem.paletteLabel = "Open in Main Editor"
            toolbarItem.toolTip = "Open the reconstructed project in SwiftCode's main editor"
            toolbarItem.image = NSImage(systemSymbolName: "arrow.up.forward.app", accessibilityDescription: nil)
            toolbarItem.target = self
            toolbarItem.action = #selector(openInMainEditorAction(_:))
            return toolbarItem

        }
    }

    public func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            NSToolbarItem.Identifier(DecompilerToolbarItem.modePicker.rawValue),
            .flexibleSpace,
            NSToolbarItem.Identifier(DecompilerToolbarItem.analyze.rawValue),
            NSToolbarItem.Identifier(DecompilerToolbarItem.cancelAnalysis.rawValue),
            NSToolbarItem.Identifier(DecompilerToolbarItem.importBinary.rawValue),
            NSToolbarItem.Identifier(DecompilerToolbarItem.saveProject.rawValue),
            NSToolbarItem.Identifier(DecompilerToolbarItem.decompileAsset.rawValue),
            NSToolbarItem.Identifier(DecompilerToolbarItem.assemble.rawValue),
            NSToolbarItem.Identifier(DecompilerToolbarItem.backendPicker.rawValue),
            NSToolbarItem.Identifier(DecompilerToolbarItem.openInMainEditor.rawValue),
            .flexibleSpace,
            NSToolbarItem.Identifier(DecompilerToolbarItem.search.rawValue),
            NSToolbarItem.Identifier(DecompilerToolbarItem.goToAddress.rawValue),
            NSToolbarItem.Identifier(DecompilerToolbarItem.goToFunction.rawValue),
            .flexibleSpace,
            NSToolbarItem.Identifier(DecompilerToolbarItem.assistToggle.rawValue),
            NSToolbarItem.Identifier(DecompilerToolbarItem.inspectorToggle.rawValue),
            NSToolbarItem.Identifier(DecompilerToolbarItem.consoleToggle.rawValue),
            NSToolbarItem.Identifier(DecompilerToolbarItem.exportAnalysis.rawValue),
            NSToolbarItem.Identifier(DecompilerToolbarItem.restoreLayout.rawValue),
        ]
    }

    public func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar) + [
            NSToolbarItem.Identifier(NSToolbarItem.Identifier.flexibleSpace.rawValue)
        ]
    }

    public func toolbarFullScreenItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier]? {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    

    @objc private func modeChanged(_ sender: NSSegmentedControl) {
        let mode: DecompilerSession.Mode = sender.selectedSegment == 0 ? .friendly : .master
        Task { await state.setMode(mode) }
    }

    @objc private func analyzeAction(_ sender: Any?) {
        state.startAnalysis()
    }

    @objc private func cancelAnalysisAction(_ sender: Any?) {
        state.cancelAnalysis()
    }

    @objc private func importBinaryAction(_ sender: Any?) {
        DecompilerCommands.perform(.openBinary, on: state)
    }

    @objc private func saveProjectAction(_ sender: Any?) {
        DecompilerCommands.perform(.saveProject, on: state)
    }

    @objc private func assistToggleAction(_ sender: Any?) {
        state.showAssist.toggle()
    }

    @objc private func inspectorToggleAction(_ sender: Any?) {
        state.showInspector.toggle()
    }

    @objc private func consoleToggleAction(_ sender: Any?) {
        state.showConsole.toggle()
    }

    @objc private func searchAction(_ sender: Any?) {
        state.pendingCommand = .search
    }

    @objc private func goToAddressAction(_ sender: Any?) {
        state.pendingCommand = .goToAddress
    }

    @objc private func goToFunctionAction(_ sender: Any?) {
        state.pendingCommand = .goToFunction
    }

    @objc private func exportAction(_ sender: Any?) {
        DecompilerCommands.perform(.exportAnalysis, on: state)
    }

    @objc private func restoreLayoutAction(_ sender: Any?) {
        DecompilerCommands.perform(.restoreLayout, on: state)
    }

    @objc private func decompileAssetAction(_ sender: Any?) {
        DecompilerCommands.perform(.decompileAsset, on: state)
    }

    @objc private func assembleAction(_ sender: Any?) {
        DecompilerCommands.perform(.assemble, on: state)
    }

    private func populateBackendPicker(_ popup: NSPopUpButton) {
        popup.removeAllItems()
        popup.addItem(withTitle: "Automatic")
        let configuration = state.reconstructedProject?.configuration
            ?? BuildConfiguration(outputFileName: "libreconstructed.dylib")
        for (backend, availability) in BackendRegistry.availableBackends(configuration: configuration) {
            popup.addItem(withTitle: backend.displayName)
            guard let item = popup.lastItem else { continue }
            item.representedObject = backend.id
            switch availability {
            case .available:
                break
            case .unavailable(let reason, let guidance):
                item.isEnabled = false
                item.toolTip = "\(reason) \(guidance)"
            }
        }
        if let selected = state.selectedBackendID {
            let index = popup.itemArray.firstIndex { ($0.representedObject as? String) == selected } ?? 0
            popup.selectItem(at: index)
        } else {
            popup.selectItem(at: 0)
        }
    }

    @objc private func backendChanged(_ sender: NSPopUpButton) {
        let id = sender.selectedItem?.representedObject as? String
        Task { await state.setBackend(id) }
    }

    @objc private func openInMainEditorAction(_ sender: Any?) {
        DecompilerCommands.perform(.openInMainEditor, on: state)
    }
}

extension DecompilerWindowController: NSMenuDelegate {
    public func menuNeedsUpdate(_ menu: NSMenu) {
        guard let popup = backendPicker, menu === popup.menu else { return }
        populateBackendPicker(popup)
    }
}
