import AppKit
import YcodeDeviceModel
import YcodeDeviceUI

@MainActor
final class DeviceHubToolbar: NSObject, NSToolbarDelegate, NSMenuDelegate, NSToolbarItemValidation {
    unowned let owner: DevicesController
    private weak var workspaceGroup: NSToolbarItemGroup?
    private weak var bootSimulatorItem: NSToolbarItem?
    private weak var zoomGroup: NSToolbarItemGroup?
    private weak var tabGroup: NSToolbarItemGroup?
    private weak var captureGroup: NSToolbarItemGroup?
    private weak var filterItem: NSMenuToolbarItem?
    private let addMenu = NSMenu(title: "Add Device")
    private let filterMenu = NSMenu(title: "Filter")
    private let moreMenu = NSMenu(title: "More Actions")

    static let workspace = NSToolbarItem.Identifier("hub.workspace")
    static let bootSimulator = NSToolbarItem.Identifier("hub.bootSimulator")
    static let add = NSToolbarItem.Identifier("hub.addDevice")
    static let filter = NSToolbarItem.Identifier("hub.filter")
    static let captureGroup = NSToolbarItem.Identifier("hub.captureGroup")
    static let resize = NSToolbarItem.Identifier("hub.resizeMode")
    static let tabSymbols = ["slider.horizontal.3", "doc.text", "info"]
    static let resizeHelp = "Enter resize mode (not available: SwiftCode’s simulator does not resize apps yet)"
    static let zoom = NSToolbarItem.Identifier("hub.zoom")
    static let open = NSToolbarItem.Identifier("hub.openInNewWindow")
    static let more = NSToolbarItem.Identifier("hub.more")
    static let tabs = NSToolbarItem.Identifier("hub.inspectorTabs")
    static let headset = NSToolbarItem.Identifier("hub.headset")

    init(owner: DevicesController) {
        self.owner = owner
        super.init()
        for m in [addMenu, filterMenu, moreMenu] { m.delegate = self }
    }

    func install(on w: NSWindow) {
        let t = NSToolbar(identifier: "SwiftCodeDeviceHub")
        t.delegate = self
        t.displayMode = .iconOnly
        t.allowsUserCustomization = false
        w.toolbar = t
    }

    static let order: [NSToolbarItem.Identifier] = [.flexibleSpace, add, filter, .toggleSidebar, .sidebarTrackingSeparator, .flexibleSpace,
                                                    workspace, bootSimulator, headset, captureGroup, zoom, open, more, .inspectorTrackingSeparator, .flexibleSpace, tabs]

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        if #available(macOS 14.0, *) { return Self.order }
        return Self.order.filter { $0 != .inspectorTrackingSeparator }
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { toolbarDefaultItemIdentifiers(toolbar) }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        func image(_ n: String, _ l: String) -> NSImage? { NSImage(systemSymbolName: n, accessibilityDescription: l) }
        switch id {
        case Self.add:
            let i = NSMenuToolbarItem(itemIdentifier: id)
            i.image = image("plus", "Add Device")
            i.label = "Add Device"
            i.toolTip = "Add Device"
            i.showsIndicator = false
            i.menu = addMenu
            return i
        case Self.filter:
            let i = NSMenuToolbarItem(itemIdentifier: id)
            i.image = image("line.3.horizontal.decrease", "Filter")
            i.label = "Filter"
            i.toolTip = "Filter"
            i.showsIndicator = false
            i.menu = filterMenu
            filterItem = i
            updateFilterLook()
            return i
        case .toggleSidebar:
            return nil
        case Self.workspace:
            let labels = ["Live Device", "Visual UI & Artboards", "Device Connect"]
            let images = ["iphone", "square.stack.3d.down.forward", "cable.connector"].enumerated().compactMap { image($0.element, labels[$0.offset]) }
            let g = NSToolbarItemGroup(itemIdentifier: id, images: images, selectionMode: .selectOne, labels: labels,
                                       target: self, action: #selector(workspaceChosen(_:)))
            for (sub, l) in zip(g.subitems, labels) { sub.toolTip = l }
            g.controlRepresentation = .expanded
            workspaceGroup = g
            updateWorkspace()
            return g
        case Self.bootSimulator:
            let i = NSToolbarItem(itemIdentifier: id)
            i.image = image("play.fill", "Boot Simulator")
            i.label = "Boot Simulator"
            i.toolTip = "Boot Simulator and Show Content"
            i.isBordered = true
            i.target = self
            i.action = #selector(bootSimulatorClicked(_:))
            bootSimulatorItem = i
            updateBootSimulator()
            return i
        case Self.captureGroup:
            let labels = ["Capture Keyboard", "Enter resize mode"]
            let images = ["keyboard", "rectangle.inset.filled"].enumerated().compactMap { image($0.element, labels[$0.offset]) }
            let g = NSToolbarItemGroup(itemIdentifier: id, images: images, selectionMode: .selectAny, labels: labels,
                                       target: self, action: #selector(captureGroupChosen(_:)))
            g.subitems[0].toolTip = "Capture Keyboard"
            g.subitems[1].toolTip = Self.resizeHelp
            g.subitems[1].autovalidates = false
            g.subitems[1].isEnabled = false
            g.subitems[1].action = nil
            g.label = "Capture Keyboard"
            g.controlRepresentation = .expanded
            captureGroup = g
            return g
        case Self.zoom:
            let labels = ["Zoom Out", "Zoom to Fit", "Zoom To Actual Size", "Zoom In"]
            let images = ["minus.magnifyingglass", "arrow.up.left.and.down.right.magnifyingglass", "1.magnifyingglass", "plus.magnifyingglass"]
                .enumerated().compactMap { image($0.element, labels[$0.offset]) }
            let g = NSToolbarItemGroup(itemIdentifier: id, images: images, selectionMode: .selectOne, labels: labels,
                                       target: self, action: #selector(zoomChosen(_:)))
            for (sub, l) in zip(g.subitems, labels) { sub.toolTip = l }
            g.controlRepresentation = .expanded
            zoomGroup = g
            updateZoom()
            return g
        case Self.open:
            let i = NSToolbarItem(itemIdentifier: id)
            i.image = image("arrow.down.right.and.arrow.up.left", "Open in New Window")
            i.label = "Open in New Window"
            i.toolTip = "Switch to compact window"
            i.isBordered = true
            i.target = self
            i.action = #selector(openClicked(_:))
            return i
        case Self.headset:
            let i = NSToolbarItem(itemIdentifier: id)
            i.image = image("eyeglasses", "View in Headset")
            i.label = "View in Headset"
            i.toolTip = "View in Headset (⌃⌘H)"
            i.isBordered = true
            i.target = self
            i.action = #selector(headsetClicked(_:))
            return i
        case Self.more:
            let i = NSMenuToolbarItem(itemIdentifier: id)
            i.image = image("ellipsis", "More Actions")
            i.label = "More Actions"
            i.toolTip = "More Actions"
            i.showsIndicator = false
            i.menu = moreMenu
            return i
        case Self.tabs:
            let labels = ["Settings", "Reports", "Info"]
            let images = Self.tabSymbols.enumerated().compactMap { image($0.element, labels[$0.offset]) }
            let g = NSToolbarItemGroup(itemIdentifier: id, images: images, selectionMode: .selectOne, labels: labels,
                                       target: self, action: #selector(tabChosen(_:)))
            for (sub, l) in zip(g.subitems, labels) { sub.toolTip = l }
            g.controlRepresentation = .expanded
            tabGroup = g
            updateTabs()
            return g
        default:
            return nil
        }
    }

    func update() {
        updateWorkspace()
        updateBootSimulator()
        updateZoom()
        updateTabs()
        updateFilterLook()
        updateCapture(owner.canvas.capturesKeyboard)
        updateSidebarItems()
        owner.view.window?.toolbar?.validateVisibleItems()
    }

    func updateWorkspace() {
        workspaceGroup?.selectedIndex = owner.workspaceMode.rawValue
    }

    func updateBootSimulator() {
        guard let item = bootSimulatorItem else { return }
        guard let r = owner.selected, owner.isLocalSimulator(r) || r.isSwiftCodeRemote else {
            item.isEnabled = false
            item.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Boot Simulator")
            item.toolTip = "Boot Simulator"
            return
        }
        item.isEnabled = true
        if r.state == "Booted" {
            item.image = NSImage(systemSymbolName: "stop.fill", accessibilityDescription: "Shut Down Simulator")
            item.label = "Shut Down"
            item.toolTip = "Shut Down Simulator"
        } else {
            item.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Boot Simulator")
            item.label = "Boot"
            item.toolTip = "Boot Simulator and Show Content"
        }
    }

    func updateZoom() {
        guard let g = zoomGroup else { return }
        switch owner.canvas.zoom {
        case .fit: g.selectedIndex = 1
        case .actual: g.selectedIndex = 2
        case .scale: break
        }
    }

    func updateTabs() { tabGroup?.selectedIndex = owner.inspectorTab.rawValue }

    func updateCapture(_ on: Bool) {
        guard let g = captureGroup else { return }
        g.setSelected(on, at: 0)
        g.setSelected(false, at: 1)
    }

    func updateSidebarItems() {
        guard #available(macOS 15.0, *), let t = owner.view.window?.toolbar else { return }
        for i in t.items {
            switch i.itemIdentifier {
            case Self.add, Self.filter: i.isHidden = !owner.sidebarShown
            case Self.captureGroup:
                if let g = i as? NSToolbarItemGroup, g.subitems.count == 2 { g.subitems[1].isHidden = owner.selected == nil }
            default: break
            }
        }
    }

    func updateFilterLook() {
        let filtered = owner.sidebarModel.filter != .all
        filterItem?.image = NSImage(systemSymbolName: filtered ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease",
                                    accessibilityDescription: "Filter")
    }

    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        switch item.itemIdentifier {
        case Self.captureGroup:
            if let g = item as? NSToolbarItemGroup, g.subitems.count == 2 { g.subitems[1].isEnabled = false }
            return owner.selected != nil
        case Self.zoom, Self.more: return owner.selected != nil
        case Self.open:
            guard let r = owner.selected, r.state == "Booted" else { return false }
            if r.isSwiftCodeRemote { return owner.makeDisplayLink != nil }
            return owner.isLocalSimulator(r)
        case Self.headset:
            let title = owner.headsetCommandTitle(for: owner.selected)
            item.label = title
            item.toolTip = title + " (⌃⌘H)"
            item.image = NSImage(systemSymbolName: title == "View in Headset" ? "eyeglasses" : "macwindow", accessibilityDescription: title)
            if #available(macOS 15.0, *) { item.isHidden = !owner.headsetControlsShown }
            return owner.canToggleHeadset(owner.selected)
        case Self.bootSimulator:
            updateBootSimulator()
            guard let r = owner.selected else { return false }
            return owner.isLocalSimulator(r) || r.isSwiftCodeRemote
        case Self.workspace: return true
        default: return true
        }
    }

    @objc func workspaceChosen(_ sender: NSToolbarItemGroup) {
        guard let mode = DeviceHubUnifiedWorkspace.HubWorkspaceMode(rawValue: sender.selectedIndex) else { return }
        owner.setWorkspaceMode(mode)
    }

    @objc func bootSimulatorClicked(_ sender: Any?) {
        owner.toggleBootSelectedSimulator(sender)
    }

    @objc func captureGroupChosen(_ sender: NSToolbarItemGroup) {
        owner.canvas.setCapturesKeyboard(sender.isSelected(at: 0))
        updateCapture(owner.canvas.capturesKeyboard)
    }

    @objc func zoomChosen(_ sender: NSToolbarItemGroup) {
        let commands: [DeviceCommand] = [.zoomOut, .zoomToFit, .physicalSize, .zoomIn]
        guard commands.indices.contains(sender.selectedIndex) else { return }
        owner.canvas.perform(commands[sender.selectedIndex])
    }

    @objc func openClicked(_ sender: Any?) { owner.openInNewWindow() }
    @objc func headsetClicked(_ sender: Any?) { owner.toggleHeadset() }

    @objc func tabChosen(_ sender: NSToolbarItemGroup) {
        owner.selectInspectorTab(DevicesController.InspectorTab(rawValue: sender.selectedIndex) ?? .settings)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if menu === addMenu {
            for i in Self.addItems(target: self, hub: owner) { menu.addItem(i) }
        } else if menu === filterMenu {
            for i in filterItems() { menu.addItem(i) }
        } else if menu === moreMenu {
            for i in moreItems() { menu.addItem(i) }
        }
    }

    static func addItems(target: AnyObject?, hub: DevicesController? = nil) -> [NSMenuItem] {
        var out: [NSMenuItem] = []
        let watches = hub?.canCreateWatches ?? false
        let visions = hub?.canCreateVisionDevices ?? false
        for (title, on) in [("iPhone…", true), ("iPad…", true), ("Apple Watch…", true), ("Apple Vision Pro…", true), ("Apple TV…", true)] {
            let action: Selector? = {
                switch title {
                case "iPhone…": return #selector(DevicesController.newIPhoneChosen(_:))
                case "iPad…": return #selector(DevicesController.newIPadChosen(_:))
                case "Apple Watch…": return watches ? #selector(DevicesController.newWatchChosen(_:)) : #selector(DevicesController.showCreateSimulatorSheet(_:))
                case "Apple Vision Pro…": return visions ? #selector(DevicesController.newVisionDeviceChosen(_:)) : #selector(DevicesController.showCreateSimulatorSheet(_:))
                case "Apple TV…": return #selector(DevicesController.newTVChosen(_:))
                default: return nil
                }
            }()
            let i = NSMenuItem(title: title, action: action, keyEquivalent: "")
            i.target = hub
            i.isEnabled = on && hub != nil
            out.append(i)
            if title == "Apple Watch…" && watches {
                let p = NSMenuItem(title: "iPhone with Paired Watch…", action: #selector(DevicesController.newPairedPhoneChosen(_:)), keyEquivalent: "")
                p.target = hub
                p.isEnabled = true
                out.append(p)
            }
        }
        out.append(.separator())
        let installRuntimes = NSMenuItem(title: "Install Simulator Runtimes…", action: #selector(DevicesController.showInstallSimulatorsSheet(_:)), keyEquivalent: "")
        installRuntimes.target = hub
        installRuntimes.isEnabled = hub != nil
        out.append(installRuntimes)

        let newSim = NSMenuItem(title: "New Simulator…", action: #selector(DevicesController.showCreateSimulatorSheet(_:)), keyEquivalent: "")
        newSim.target = hub
        newSim.isEnabled = hub != nil
        out.append(newSim)

        if let selected = hub?.selected, (hub?.isLocalSimulator(selected) == true || selected.isSwiftCodeRemote) {
            let clone = NSMenuItem(title: "Clone Selected Simulator…", action: #selector(DevicesController.showCloneSimulatorSheet(_:)), keyEquivalent: "")
            clone.target = hub
            out.append(clone)
        }

        let pair = NSMenuItem(title: "Pair Nearby Device…", action: #selector(DevicesController.pairNearbyChosen(_:)), keyEquivalent: "")
        pair.target = hub
        pair.isEnabled = hub != nil
        out.append(pair)
        return out
    }

    @objc func addSimulator(_ sender: Any?) { SettingsWindowController.shared.show(pane: "Simulators") }

    func filterItems() -> [NSMenuItem] {
        var out: [NSMenuItem] = []
        for f in HubFilter.allCases {
            let i = NSMenuItem(title: f.rawValue, action: #selector(filterChosen(_:)), keyEquivalent: "")
            i.target = self
            i.representedObject = f.rawValue
            i.state = owner.sidebarModel.filter == f ? .on : .off
            out.append(i)
        }
        out.append(.separator())
        let sort = NSMenuItem(title: "Sort By", action: nil, keyEquivalent: "")
        let sm = NSMenu(title: "Sort By")
        for s in HubSort.allCases {
            let i = NSMenuItem(title: s.rawValue, action: #selector(sortChosen(_:)), keyEquivalent: "")
            i.target = self
            i.representedObject = s.rawValue
            i.state = owner.sortChosen && owner.sidebarModel.sort == s ? .on : .off
            sm.addItem(i)
        }
        sort.submenu = sm
        out.append(sort)
        return out
    }

    @objc func filterChosen(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let f = HubFilter(rawValue: raw) else { return }
        owner.setFilter(f)
        updateFilterLook()
    }

    @objc func sortChosen(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let s = HubSort(rawValue: raw) else { return }
        owner.setSort(owner.sortChosen && owner.sidebarModel.sort == s ? nil : s)
    }

    func moreItems() -> [NSMenuItem] {
        guard let r = owner.selected else { return [] }
        var out = owner.lifecycleItems(for: r) + owner.headsetMenuItems(for: r)
        let bezels = NSMenuItem(title: owner.canvas.showsBezels ? "Hide Bezels" : "Show Bezels", action: #selector(toggleBezels(_:)), keyEquivalent: "")
        bezels.target = self
        let stats = NSMenuItem(title: "Show Frame Rate", action: #selector(toggleStatistics(_:)), keyEquivalent: "")
        stats.target = self
        stats.state = owner.canvas.showsStatistics ? .on : .off
        out += [bezels, stats]

        let isSim = owner.isLocalSimulator(r) || r.isSwiftCodeRemote
        if isSim {
            out.append(.separator())
            out.append(configurationSubmenu(for: r))
            out.append(locationSubmenu(for: r))
            out.append(batteryAndNetworkSubmenu(for: r))

            if DeviceHubUnifiedWorkspace.isIPad(for: r) {
                out.append(iPadCapabilitiesSubmenu(for: r))
            }

            out.append(.separator())
            let clone = NSMenuItem(title: "Clone Simulator…", action: #selector(DevicesController.showCloneSimulatorSheet(_:)), keyEquivalent: "")
            clone.target = owner
            out.append(clone)

            let bootAll = NSMenuItem(title: "Quick Boot All Simulators", action: #selector(DevicesController.quickBootAllSimulators(_:)), keyEquivalent: "")
            bootAll.target = owner
            out.append(bootAll)

            let shutdownAll = NSMenuItem(title: "Shut Down All Simulators", action: #selector(DevicesController.shutDownAllSimulators(_:)), keyEquivalent: "")
            shutdownAll.target = owner
            out.append(shutdownAll)
        }

        if owner.isLocalSimulator(r) {
            out.append(.separator())
            out += owner.localMenuItems(for: r)
            let live = NSMenuItem(title: owner.localLiveViewEnabled ? "Hide Live View" : "Show Live View",
                                  action: #selector(DevicesController.toggleLocalLiveViewChosen(_:)), keyEquivalent: "")
            live.target = owner
            live.representedObject = r.identifier
            out.append(live)
        }
        if owner.isConnectPeer(r) {
            out.append(.separator())
            let logs = NSMenuItem(title: "View Logs", action: #selector(DevicesController.viewLogsChosen(_:)), keyEquivalent: "")
            logs.target = owner
            logs.representedObject = r.identifier
            out.append(logs)
            let forget = NSMenuItem(title: "Forget Device", action: #selector(DevicesController.forgetConnectDeviceChosen(_:)), keyEquivalent: "")
            forget.target = owner
            forget.representedObject = r.identifier
            out.append(forget)
        }
        if let i = owner.rows.firstIndex(where: { $0.identifier == r.identifier }), isSim {
            out.append(.separator())
            let erase = NSMenuItem(title: DevicesController.eraseTitle, action: #selector(DevicesController.eraseChosen(_:)), keyEquivalent: "")
            erase.target = owner
            erase.tag = i
            out.append(erase)

            let eraseAll = NSMenuItem(title: "Erase All Simulators…", action: #selector(DevicesController.eraseAllSimulatorsChosen(_:)), keyEquivalent: "")
            eraseAll.target = owner
            out.append(eraseAll)
        }
        return out
    }

    private func configurationSubmenu(for r: DeviceRow) -> NSMenuItem {
        let menu = NSMenu(title: "Device Configuration")
        let light = NSMenuItem(title: "Appearance: Light Mode", action: #selector(DevicesController.setSimulatorAppearanceLight(_:)), keyEquivalent: "")
        light.target = owner
        let dark = NSMenuItem(title: "Appearance: Dark Mode", action: #selector(DevicesController.setSimulatorAppearanceDark(_:)), keyEquivalent: "")
        dark.target = owner
        menu.addItem(light)
        menu.addItem(dark)
        menu.addItem(.separator())
        let contrast = NSMenuItem(title: "Increase Contrast (Accessibility)", action: #selector(DevicesController.toggleSimulatorIncreaseContrast(_:)), keyEquivalent: "")
        contrast.target = owner
        let motion = NSMenuItem(title: "Reduce Motion (Accessibility)", action: #selector(DevicesController.toggleSimulatorReduceMotion(_:)), keyEquivalent: "")
        motion.target = owner
        menu.addItem(contrast)
        menu.addItem(motion)

        let item = NSMenuItem(title: "Device Configuration", action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }

    private func locationSubmenu(for r: DeviceRow) -> NSMenuItem {
        let menu = NSMenu(title: "Simulate Location")
        let applePark = NSMenuItem(title: "Apple Park (Cupertino)", action: #selector(DevicesController.simulateLocationApplePark(_:)), keyEquivalent: "")
        applePark.target = owner
        let cityRun = NSMenuItem(title: "City Run (Scenario)", action: #selector(DevicesController.simulateLocationCityRun(_:)), keyEquivalent: "")
        cityRun.target = owner
        let freeway = NSMenuItem(title: "Freeway Drive (Scenario)", action: #selector(DevicesController.simulateLocationFreewayDrive(_:)), keyEquivalent: "")
        freeway.target = owner
        let custom = NSMenuItem(title: "Custom Coordinates…", action: #selector(DevicesController.simulateLocationCustom(_:)), keyEquivalent: "")
        custom.target = owner
        let clear = NSMenuItem(title: "Clear Location", action: #selector(DevicesController.clearSimulatedLocation(_:)), keyEquivalent: "")
        clear.target = owner

        menu.addItem(applePark)
        menu.addItem(cityRun)
        menu.addItem(freeway)
        menu.addItem(.separator())
        menu.addItem(custom)
        menu.addItem(clear)

        let item = NSMenuItem(title: "Simulate Location", action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }

    private func batteryAndNetworkSubmenu(for r: DeviceRow) -> NSMenuItem {
        let menu = NSMenu(title: "Simulate Battery & Network")
        let b100 = NSMenuItem(title: "Battery: 100% (Charged)", action: #selector(DevicesController.setSimulatorBattery100(_:)), keyEquivalent: "")
        b100.target = owner
        let b50 = NSMenuItem(title: "Battery: 50% (Discharging)", action: #selector(DevicesController.setSimulatorBattery50(_:)), keyEquivalent: "")
        b50.target = owner
        let b20 = NSMenuItem(title: "Battery: 20% (Low Power)", action: #selector(DevicesController.setSimulatorBattery20(_:)), keyEquivalent: "")
        b20.target = owner
        menu.addItem(b100)
        menu.addItem(b50)
        menu.addItem(b20)
        menu.addItem(.separator())
        let n5g = NSMenuItem(title: "Network: 5G Active", action: #selector(DevicesController.setSimulatorNetwork5G(_:)), keyEquivalent: "")
        n5g.target = owner
        let nWifi = NSMenuItem(title: "Network: Wi-Fi Active", action: #selector(DevicesController.setSimulatorNetworkWiFi(_:)), keyEquivalent: "")
        nWifi.target = owner
        let nOff = NSMenuItem(title: "Network: Offline (Searching)", action: #selector(DevicesController.setSimulatorNetworkOffline(_:)), keyEquivalent: "")
        nOff.target = owner
        let nClear = NSMenuItem(title: "Reset Status Bar Overrides", action: #selector(DevicesController.clearSimulatorNetworkOverrides(_:)), keyEquivalent: "")
        nClear.target = owner
        menu.addItem(n5g)
        menu.addItem(nWifi)
        menu.addItem(nOff)
        menu.addItem(.separator())
        menu.addItem(nClear)

        let item = NSMenuItem(title: "Simulate Battery & Network", action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }

    private func iPadCapabilitiesSubmenu(for r: DeviceRow) -> NSMenuItem {
        let menu = NSMenu(title: "iPadOS Tablet Capabilities")
        let stage = NSMenuItem(title: "Toggle Stage Manager", action: #selector(DevicesController.toggleStageManagerChosen(_:)), keyEquivalent: "")
        stage.target = owner
        let pDouble = NSMenuItem(title: "Simulate Apple Pencil Double-Tap", action: #selector(DevicesController.simulatePencilDoubleTapChosen(_:)), keyEquivalent: "")
        pDouble.target = owner
        let pSqueeze = NSMenuItem(title: "Simulate Apple Pencil Squeeze", action: #selector(DevicesController.simulatePencilSqueezeChosen(_:)), keyEquivalent: "")
        pSqueeze.target = owner
        menu.addItem(stage)
        menu.addItem(.separator())
        menu.addItem(pDouble)
        menu.addItem(pSqueeze)

        let item = NSMenuItem(title: "iPadOS Tablet Capabilities", action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }

    @objc func toggleBezels(_ sender: Any?) {
        owner.canvas.showsBezels.toggle()
        owner.defaults.set(owner.canvas.showsBezels, forKey: DevicesController.bezelsKey)
    }

    @objc func toggleStatistics(_ sender: Any?) { owner.canvas.showsStatistics.toggle() }
}
