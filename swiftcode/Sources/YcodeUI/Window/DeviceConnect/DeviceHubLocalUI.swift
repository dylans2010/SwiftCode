#if os(macOS)
import AppKit
import SwiftUI
import UniformTypeIdentifiers
import YcodeDeviceModel
import YcodeDeviceUI
import YcodeIDECore
import SwiftCodeConnect



extension DeviceHubSimctl {
    @discardableResult
    static func runTool(_ executable: String, _ arguments: [String], timeout: TimeInterval = 30) -> (status: Int32, output: String) {
        do {
            let result = try DeviceConnectProcessRunner.shared.runBlocking(
                executableURL: URL(fileURLWithPath: executable),
                arguments: arguments,
                timeout: timeout
            )
            return (result.exitCode, result.stdout + result.stderr)
        } catch let error as DeviceConnectProcessError {
            if case .timedOut = error {
                return (-2, "timed out")
            }
            return (-1, error.localizedDescription)
        } catch {
            return (-1, error.localizedDescription)
        }
    }
}

extension DevicesController {

    

    func isConnectPeer(_ r: DeviceRow) -> Bool { connectPeers[r.identifier] != nil }

    func localItem(_ title: String, _ action: Selector, _ r: DeviceRow) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: "")
        i.target = self
        i.representedObject = r.identifier
        return i
    }

    
    
    
    func localQuickActions(for r: DeviceRow) -> [(String, Selector)] {
        guard isLocalSimulator(r), r.state == "Booted" else { return [] }
        let recording = videoRecordings[r.identifier] != nil
        return [
            ("Install App…", #selector(installAppChosen(_:))),
            ("Launch App…", #selector(launchAppChosen(_:))),
            ("Terminate App…", #selector(terminateAppChosen(_:))),
            (recording ? "Stop Recording" : "Record Video", #selector(recordVideoChosen(_:))),
            ("View Logs", #selector(viewLogsChosen(_:))),
            ("Status Bar Overrides…", #selector(statusBarChosen(_:))),
        ]
    }

    func localMenuItems(for r: DeviceRow) -> [NSMenuItem] {
        localQuickActions(for: r).map { localItem($0.0, $0.1, r) }
    }

    

    @objc func toggleLocalLiveViewChosen(_ sender: Any?) {
        localLiveViewEnabled.toggle()
        for id in Array(localLinks.keys) { closeLocalLink(id) }
        canvas.showBanner(localLiveViewEnabled ? "Live view on" : "Live view off", seconds: 2)
        showDetails()
    }

    @objc func localLiveSwitchToggled(_ sender: NSSwitch) {
        localLiveViewEnabled = sender.state == .on
        for id in Array(localLinks.keys) { closeLocalLink(id) }
        refreshCanvas()
    }

    

    @objc func installAppChosen(_ sender: Any?) {
        guard let r = row(from: sender), isLocalSimulator(r), r.state == "Booted" else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Install"
        panel.message = "Choose a .app bundle to install on “\(r.name)”"
        guard let window = view.window else { return }
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            Task {
                do {
                    try await SimctlService().installApplication(udid: r.identifier, appPath: url.path)
                    self.canvas.showBanner("Installed \(url.lastPathComponent)", seconds: 3)
                } catch {
                    self.canvas.showBanner("Install failed: \(error.localizedDescription)", seconds: 4)
                }
            }
        }
    }

    private func askBundleID(title: String, message: String, placeholder: String = "com.example.app",
                             initial: String = "") -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        let field = NSTextField(string: initial)
        field.placeholderString = placeholder
        field.frame = NSRect(x: 0, y: 0, width: 300, height: 24)
        alert.accessoryView = field
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        guard let w = view.window, w.isVisible else {
            return alert.runModal() == .alertFirstButtonReturn ? field.stringValue : nil
        }
        var result: String?
        alert.beginSheetModal(for: w) { response in
            result = response == .alertFirstButtonReturn ? field.stringValue : nil
        }
        return result
    }

    @objc func launchAppChosen(_ sender: Any?) {
        guard let r = row(from: sender), isLocalSimulator(r), r.state == "Booted" else { return }
        guard let bundleID = askBundleID(title: "Launch App",
                                       message: "Enter the bundle identifier of an app installed on “\(r.name)”.") else { return }
        let id = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return }
        Task {
            do {
                try await SimctlService().launchApplication(udid: r.identifier, bundleID: id, args: [])
                canvas.showBanner("Launched \(id)", seconds: 3)
            } catch {
                canvas.showBanner("Launch failed: \(error.localizedDescription)", seconds: 4)
            }
        }
    }

    @objc func terminateAppChosen(_ sender: Any?) {
        guard let r = row(from: sender), isLocalSimulator(r), r.state == "Booted" else { return }
        guard let bundleID = askBundleID(title: "Terminate App",
                                       message: "Enter the bundle identifier of a running app on “\(r.name)”.") else { return }
        let id = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return }
        Task {
            do {
                try await SimctlService().terminateApplication(udid: r.identifier, bundleID: id)
                canvas.showBanner("Terminated \(id)", seconds: 3)
            } catch {
                canvas.showBanner("Terminate failed: \(error.localizedDescription)", seconds: 4)
            }
        }
    }

    

    @objc func recordVideoChosen(_ sender: Any?) {
        guard let r = row(from: sender), isLocalSimulator(r), r.state == "Booted" else { return }
        if let rec = videoRecordings[r.identifier] {
            videoRecordings.removeValue(forKey: r.identifier)
            Task.detached { DeviceHubSimctl.stopRecording(rec.process) }
            canvas.showBanner("Recording saved to \(rec.url.lastPathComponent)", seconds: 4)
            showDetails()
            return
        }
        do {
            let (process, url) = try DeviceHubSimctl.startRecording(udid: r.identifier, deviceName: r.name,
                                                                  into: DeviceLiveSession.captureDirectory)
            videoRecordings[r.identifier] = (process, url)
            canvas.showBanner("Recording “\(r.name)”…", seconds: 3)
            showDetails()
        } catch {
            canvas.showBanner("Could not start recording: \(error.localizedDescription)", seconds: 4)
        }
    }

    

    @objc func viewLogsChosen(_ sender: Any?) {
        guard let r = row(from: sender) else { return }
        if isLocalSimulator(r), r.state == "Booted" {
            let wc = DeviceHubLogWindowController(title: "Logs — \(r.name)", udid: r.identifier, peer: nil)
            wc.showWindow(nil)
            wc.start()
        } else if let peer = connectPeers[r.identifier] {
            let wc = DeviceHubLogWindowController(title: "Logs — \(r.name)", udid: nil, peer: peer)
            wc.showWindow(nil)
            wc.start()
        } else {
            NSSound.beep()
        }
    }

    @objc func connectLogsChosen(_ sender: Any?) {
        viewLogsChosen(sender)
    }

    

    @objc func statusBarChosen(_ sender: Any?) {
        guard let r = row(from: sender), isLocalSimulator(r), r.state == "Booted" else { return }
        presentStatusBarSheet(for: r)
    }

    func presentStatusBarSheet(for r: DeviceRow) {
        let alert = NSAlert()
        alert.messageText = "Status Bar Overrides — \(r.name)"
        alert.informativeText = "Override the simulated status bar (time, battery, Wi-Fi, operator). Overrides persist until cleared or the device reboots."

        func field(_ placeholder: String, _ width: CGFloat = 90) -> NSTextField {
            let f = NSTextField(string: "")
            f.placeholderString = placeholder
            f.frame = NSRect(x: 0, y: 0, width: width, height: 22)
            return f
        }
        let time = field("9:41")
        let battery = field("100")
        let wifi = field("3")
        let op = field("Carrier", 120)
        let statePop = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 110, height: 24), pullsDown: false)
        statePop.addItems(withTitles: ["charged", "discharging", "charging", "full"])
        statePop.selectItem(at: 0)

        let grid = NSGridView(views: [
            [NSTextField(labelWithString: "Time:"), time],
            [NSTextField(labelWithString: "Battery Level:"), battery],
            [NSTextField(labelWithString: "Battery State:"), statePop],
            [NSTextField(labelWithString: "Wi-Fi Bars:"), wifi],
            [NSTextField(labelWithString: "Operator:"), op],
        ])
        grid.rowSpacing = 8
        grid.columnSpacing = 8
        grid.translatesAutoresizingMaskIntoConstraints = false
        alert.accessoryView = grid
        alert.addButton(withTitle: "Apply")
        alert.addButton(withTitle: "Clear Overrides")
        alert.addButton(withTitle: "Cancel")

        func run(_ apply: Bool) {
            if apply {
                let level = Int(battery.stringValue)
                let bars = Int(wifi.stringValue)
                let (status, output) = DeviceHubSimctl.overrideStatusBar(
                    udid: r.identifier,
                    time: time.stringValue.isEmpty ? nil : time.stringValue,
                    batteryLevel: level,
                    batteryState: statePop.titleOfSelectedItem,
                    wifiBars: bars,
                    operatorName: op.stringValue.isEmpty ? nil : op.stringValue)
                canvas.showBanner(status == 0 ? "Status bar overridden" : "Override failed: \(output)", seconds: status == 0 ? 3 : 5)
            } else {
                let (status, output) = DeviceHubSimctl.clearStatusBar(udid: r.identifier)
                canvas.showBanner(status == 0 ? "Status bar overrides cleared" : "Clear failed: \(output)", seconds: status == 0 ? 3 : 5)
            }
        }

        if let w = view.window, w.isVisible {
            alert.beginSheetModal(for: w) { response in
                if response == .alertFirstButtonReturn { run(true) }
                else if response == .alertSecondButtonReturn { run(false) }
            }
        } else {
            let response = alert.runModal()
            if response == .alertFirstButtonReturn { run(true) }
            else if response == .alertSecondButtonReturn { run(false) }
        }
    }

    

    @objc func renameDeviceChosen(_ sender: Any?) {
        guard let r = row(from: sender), isLocalSimulator(r), r.state != "Booted" else { return }
        let alert = NSAlert()
        alert.messageText = "Rename “\(r.name)”"
        alert.informativeText = "The simulator must be shut down to rename it."
        let field = NSTextField(string: r.name)
        field.frame = NSRect(x: 0, y: 0, width: 280, height: 24)
        alert.accessoryView = field
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        func apply() {
            let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, name != r.name else { return }
            let (status, output) = DeviceHubSimctl.renameDevice(udid: r.identifier, to: name)
            canvas.showBanner(status == 0 ? "Renamed to “\(name)”" : "Rename failed: \(output)", seconds: status == 0 ? 3 : 5)
            refreshLocalRows()
        }
        if let w = view.window, w.isVisible {
            alert.beginSheetModal(for: w) { if $0 == .alertFirstButtonReturn { apply() } }
        } else if alert.runModal() == .alertFirstButtonReturn { apply() }
    }

    @objc func deleteLocalDeviceChosen(_ sender: Any?) {
        guard let r = row(from: sender), isLocalSimulator(r), r.state != "Booted" else { return }
        let alert = NSAlert()
        alert.messageText = "Delete “\(r.name)”?"
        alert.informativeText = "The simulator and all of its data will be permanently deleted. You can’t undo this action."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        func apply() {
            Task {
                SimulatorManager.shared.selectedDeviceID = r.identifier
                await SimulatorManager.shared.deleteSelectedDevice()
                refreshLocalRows()
            }
        }
        if let w = view.window, w.isVisible {
            alert.beginSheetModal(for: w) { if $0 == .alertFirstButtonReturn { apply() } }
        } else if alert.runModal() == .alertFirstButtonReturn { apply() }
    }

    

    
    
    @objc func newSimulatorChosen(_ sender: Any?) {
        presentNewSimulatorSheet()
    }

    func presentNewSimulatorSheet() {
        let hosting = NSHostingController(rootView: SimulatorCreationView())
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable]
        window.title = "New Simulator"
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 520, height: 620))
        guard let w = view.window else { window.makeKeyAndOrderFront(nil); return }
        w.beginSheet(window) { [weak self] _ in
            
            
            self?.refreshLocalRows()
        }
    }

    

    @objc func pairNearbyChosen(_ sender: Any?) {
        presentPairNearbySheet()
    }

    func presentPairNearbySheet() {
        let hosting = NSHostingController(rootView: HubNearbyDevicesView(hub: self))
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable]
        window.title = "Pair Nearby Device"
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 540, height: 480))
        guard let w = view.window else { window.makeKeyAndOrderFront(nil); return }
        w.beginSheet(window)
    }

    
    func pairConnectDevice(_ peer: HubConnectPeer) {
        let rowID = "connect:\(peer.device.id)"
        
        
        var row = DeviceRow.shutDownSwiftCodeSimulator(name: peer.device.name, identifier: rowID)
        row.isSwiftCodeRemote = false
        row.platform = "iOS"
        row.osVersion = peer.device.txtRecord["osVersion"] ?? ""
        row.state = peer.isActive ? "connected" : "pairing"
        row.model = peer.device.deviceType == "iOS" ? "iPhone" : peer.device.deviceType
        row.isAvailable = true
        connectPeers[rowID] = peer
        peer.onStateChange = { [weak self] _ in
            guard let self, var r = self.allRows.first(where: { $0.identifier == rowID }) else { return }
            r.state = peer.isActive ? "connected" : (peer.session == nil ? "disconnected" : "pairing")
            r.isAvailable = peer.session != nil
            self.upsertDeviceRow(r)
            if self.isViewLoaded { self.showDetails() }
        }
        upsertDeviceRow(row)
        if let i = rows.firstIndex(where: { $0.identifier == rowID }) { select(row: i) }
    }

    func isPairedConnectDevice(_ deviceID: String) -> Bool {
        connectPeers["connect:\(deviceID)"] != nil
    }

    @objc func forgetConnectDeviceChosen(_ sender: Any?) {
        guard let r = row(from: sender), connectPeers[r.identifier] != nil else { return }
        forgetConnectDevice(r.identifier)
    }

    func forgetConnectDevice(_ rowIdentifier: String) {
        guard let peer = connectPeers[rowIdentifier] else { return }
        let alert = NSAlert()
        alert.messageText = "Forget “\(peer.device.name)”?"
        alert.informativeText = "The device is disconnected and removed from the Device Hub. Pair it again from Pair Nearby Device…."
        alert.addButton(withTitle: "Forget")
        alert.addButton(withTitle: "Cancel")
        func apply() {
            peer.disconnect()
            removeDeviceRow(identifier: rowIdentifier)
            if selected?.identifier == rowIdentifier { select(row: 0) }
        }
        if let w = view.window, w.isVisible {
            alert.beginSheetModal(for: w) { if $0 == .alertFirstButtonReturn { apply() } }
        } else if alert.runModal() == .alertFirstButtonReturn { apply() }
    }

    
    func connectInfoRows(for r: DeviceRow) -> [(String, String)] {
        guard let peer = connectPeers[r.identifier] else { return [] }
        var out = [("Connection", peer.stateText), ("Endpoint", "\(peer.device.host):\(peer.device.port)")]
        if let s = peer.session {
            out.append(("Permissions", s.grantedPermissions.isEmpty ? "None yet" : s.grantedPermissions.map(\.rawValue).sorted().joined(separator: ", ")))
        }
        if !peer.deviceItems.isEmpty {
            out.append(("Paired Devices", peer.deviceItems.map { "\($0.name) (\($0.platform) \($0.osVersion))" }.joined(separator: ", ")))
        }
        if let e = peer.lastError { out.append(("Last Error", e)) }
        return out
    }

    

    
    
    
    
    func localSettingsControls() -> NSView {
        let r = selected
        let booted = r?.state == "Booted"
        let recording = r.map { videoRecordings[$0.identifier] != nil } ?? false

        func control(_ title: String, _ sel: Selector, symbol: String, enabled: Bool = true) -> InspectorCard.Row {
            let b = NSButton(title: title, target: self, action: sel)
            b.bezelStyle = .push
            b.controlSize = .small
            b.isEnabled = enabled && booted
            b.setAccessibilityLabel(title)
            return InspectorCard.Row(symbol: symbol, title: title, control: b)
        }
        func toggle(_ title: String, _ sel: Selector, symbol: String, on: Bool) -> InspectorCard.Row {
            let s = NSSwitch()
            s.state = on ? .on : .off
            s.target = self
            s.action = sel
            s.controlSize = .small
            s.isEnabled = booted
            s.setAccessibilityLabel(title)
            return InspectorCard.Row(symbol: symbol, title: title, control: s)
        }
        func popup(_ titles: [String], selectedIndex: Int, sel: Selector) -> NSPopUpButton {
            let p = NSPopUpButton(frame: .zero, pullsDown: false)
            p.addItems(withTitles: titles)
            p.selectItem(at: selectedIndex)
            p.target = self
            p.action = sel
            p.isBordered = false
            p.controlSize = .small
            p.isEnabled = booted
            return p
        }

        var cards: [NSView] = []

        
        let appearancePop = popup(["Light", "Dark"], selectedIndex: 0, sel: #selector(localAppearancePopupChanged(_:)))
        let contrastSwitch = toggle("Increase Contrast", #selector(localIncreaseContrastToggled(_:)), symbol: "circle.righthalf.filled", on: false)
        let motionSwitch = toggle("Reduce Motion", #selector(localReduceMotionToggled(_:)), symbol: "circle.dotted.and.circle", on: false)
        let textSlider = NSSlider(value: 3, minValue: 0, maxValue: 11, target: self, action: #selector(localContentSizeChanged(_:)))
        textSlider.numberOfTickMarks = 12
        textSlider.allowsTickMarkValuesOnly = true
        textSlider.isContinuous = false
        textSlider.controlSize = .small
        textSlider.isEnabled = booted
        let appearanceRows: [InspectorCard.Row] = [
            InspectorCard.Row(symbol: "circle.lefthalf.filled", title: "Appearance", control: appearancePop),
            InspectorCard.Row(symbol: "textformat.size", title: "Dynamic Type", control: textSlider),
            contrastSwitch,
            motionSwitch
        ]
        cards.append(InspectorCard(rows: appearanceRows, identifier: "settings-local-appearance"))

        
        let locationChoices = [
            "None (Clear)",
            "Apple Park",
            "City Run",
            "Freeway Drive",
            "San Francisco",
            "New York City",
            "Custom Coordinates…"
        ]
        let locPop = popup(locationChoices, selectedIndex: 0, sel: #selector(localLocationPopupChanged(_:)))
        let locRows: [InspectorCard.Row] = [
            InspectorCard.Row(symbol: "location", title: "Location", control: locPop)
        ]
        cards.append(InspectorCard(rows: locRows, identifier: "settings-local-location"))

        
        let batterySlider = NSSlider(value: 100, minValue: 0, maxValue: 100, target: self, action: #selector(localBatterySliderChanged(_:)))
        batterySlider.isContinuous = false
        batterySlider.controlSize = .small
        batterySlider.isEnabled = booted
        let netPop = popup(["Wi-Fi", "5G", "5G+", "LTE", "3G", "Reset"], selectedIndex: 0, sel: #selector(localNetworkPopupChanged(_:)))
        let powerRows: [InspectorCard.Row] = [
            InspectorCard.Row(symbol: "battery.100", title: "Battery Level", control: batterySlider),
            InspectorCard.Row(symbol: "antenna.radiowaves.left.and.right", title: "Network", control: netPop),
            control("Status Bar Overrides…", #selector(statusBarChosen(_:)), symbol: "gearshape")
        ]
        cards.append(InspectorCard(rows: powerRows, identifier: "settings-local-power"))

        
        if let r, DeviceHubUnifiedWorkspace.isIPad(for: r) {
            let stageSwitch = toggle("Stage Manager", #selector(localStageManagerToggled(_:)), symbol: "square.split.2x2", on: false)
            let iPadRows: [InspectorCard.Row] = [
                stageSwitch,
                control("Pencil Double-Tap", #selector(simulatePencilDoubleTapChosen(_:)), symbol: "applepencil"),
                control("Pencil Squeeze", #selector(simulatePencilSqueezeChosen(_:)), symbol: "hand.tap")
            ]
            cards.append(InspectorCard(rows: iPadRows, identifier: "settings-local-ipad"))
        }

        
        var quickRows: [InspectorCard.Row] = [
            control("Clone Simulator…", #selector(showCloneSimulatorSheet(_:)), symbol: "square.on.square"),
            control("Shake Device", #selector(shakeChosen(_:)), symbol: "iphone.radiowaves.left.and.right"),
            control("Memory Warning", #selector(memoryPressureChosen(_:)), symbol: "memorychip"),
            toggle("Slow Animations", #selector(slowAnimationsChosen(_:)), symbol: "tortoise", on: isSlowAnimationsEnabled),
            toggle("Standby Mode", #selector(standbyChosen(_:)), symbol: "moon.zzz", on: isStandbyModeEnabled),
        ]
        if let r, isLocalSimulator(r) {
            quickRows += [
                toggle("Live View", #selector(localLiveSwitchToggled(_:)), symbol: "eye", on: localLiveViewEnabled),
                control(recording ? "Stop Recording" : "Record Video", #selector(recordVideoChosen(_:)), symbol: "record.circle"),
                control("View Logs", #selector(viewLogsChosen(_:)), symbol: "text.alignleft"),
                control("Install App…", #selector(installAppChosen(_:)), symbol: "square.and.arrow.down"),
                control("Launch App…", #selector(launchAppChosen(_:)), symbol: "play"),
                control("Terminate App…", #selector(terminateAppChosen(_:)), symbol: "stop"),
            ]
        }
        cards.append(InspectorCard(rows: quickRows, identifier: "settings-local-actions"))

        let stack = NSStackView(views: cards)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Self.cardSpacing
        stack.identifier = .init("settings-local-controls")
        if !booted {
            let l = NSTextField(wrappingLabelWithString: "Start the simulator to use these controls.")
            l.textColor = .secondaryLabelColor
            l.font = .systemFont(ofSize: 11)
            l.identifier = .init("settings-stopped")
            l.preferredMaxLayoutWidth = InspectorCard.width - 20
            stack.addArrangedSubview(l)
        }
        return stack
    }

    @objc func localAppearancePopupChanged(_ sender: NSPopUpButton) {
        guard let r = selected, isLocalSimulator(r) || r.isSwiftCodeRemote else { return }
        let isDark = sender.indexOfSelectedItem == 1
        Task { [weak self] in
            try? await DeviceHubSimulatorInstaller.setAppearance(udid: r.identifier, appearance: isDark ? "dark" : "light")
            await MainActor.run { self?.canvas.showBanner("Appearance: \(isDark ? "Dark" : "Light")", seconds: 2) }
        }
    }

    @objc func localLocationPopupChanged(_ sender: NSPopUpButton) {
        guard let r = selected, isLocalSimulator(r) || r.isSwiftCodeRemote else { return }
        let title = sender.titleOfSelectedItem ?? ""
        Task { [weak self] in
            switch title {
            case "Apple Park":
                try? await DeviceHubSimulatorInstaller.setLocation(udid: r.identifier, latitude: 37.3346, longitude: -122.0090)
                await MainActor.run { self?.canvas.showBanner("Location: Apple Park", seconds: 2) }
            case "City Run":
                try? await DeviceHubSimulatorInstaller.runLocationScenario(udid: r.identifier, scenario: "City Run")
                await MainActor.run { self?.canvas.showBanner("Scenario: City Run", seconds: 2) }
            case "Freeway Drive":
                try? await DeviceHubSimulatorInstaller.runLocationScenario(udid: r.identifier, scenario: "Freeway Drive")
                await MainActor.run { self?.canvas.showBanner("Scenario: Freeway Drive", seconds: 2) }
            case "San Francisco":
                try? await DeviceHubSimulatorInstaller.setLocation(udid: r.identifier, latitude: 37.7749, longitude: -122.4194)
                await MainActor.run { self?.canvas.showBanner("Location: San Francisco", seconds: 2) }
            case "New York City":
                try? await DeviceHubSimulatorInstaller.setLocation(udid: r.identifier, latitude: 40.7128, longitude: -74.0060)
                await MainActor.run { self?.canvas.showBanner("Location: New York City", seconds: 2) }
            case "Custom Coordinates…":
                await MainActor.run { self?.simulateLocationCustom(sender) }
            default:
                try? await DeviceHubSimulatorInstaller.clearLocation(udid: r.identifier)
                await MainActor.run { self?.canvas.showBanner("Location cleared", seconds: 2) }
            }
        }
    }

    @objc func localContentSizeChanged(_ sender: NSSlider) {
        guard let r = selected, isLocalSimulator(r) || r.isSwiftCodeRemote else { return }
        let sizes = [
            "extra-small", "small", "medium", "large", "extra-large",
            "extra-extra-large", "extra-extra-extra-large",
            "accessibility-medium", "accessibility-large",
            "accessibility-extra-large", "accessibility-extra-extra-large",
            "accessibility-extra-extra-extra-large"
        ]
        let idx = min(sizes.count - 1, max(0, sender.integerValue))
        let size = sizes[idx]
        Task { [weak self] in
            try? await DeviceHubSimulatorInstaller.setContentSize(udid: r.identifier, size: size)
            await MainActor.run { self?.canvas.showBanner("Text Size: \(size)", seconds: 2) }
        }
    }

    @objc func localBatterySliderChanged(_ sender: NSSlider) {
        guard let r = selected, isLocalSimulator(r) || r.isSwiftCodeRemote else { return }
        let level = sender.integerValue
        Task { [weak self] in
            try? await DeviceHubSimulatorInstaller.overrideStatusBar(udid: r.identifier, batteryLevel: level, batteryState: "discharging")
            await MainActor.run { self?.canvas.showBanner("Battery: \(level)%", seconds: 2) }
        }
    }

    @objc func localNetworkPopupChanged(_ sender: NSPopUpButton) {
        guard let r = selected, isLocalSimulator(r) || r.isSwiftCodeRemote else { return }
        let type = sender.titleOfSelectedItem?.lowercased() ?? "wifi"
        Task { [weak self] in
            if type == "reset" {
                try? await DeviceHubSimulatorInstaller.clearStatusBar(udid: r.identifier)
                await MainActor.run { self?.canvas.showBanner("Status bar overrides reset", seconds: 2) }
            } else {
                try? await DeviceHubSimulatorInstaller.overrideStatusBar(udid: r.identifier, dataNetwork: type, wifiMode: "active", wifiBars: 3, cellularMode: "active", cellularBars: 4)
                await MainActor.run { self?.canvas.showBanner("Network: \(type.uppercased())", seconds: 2) }
            }
        }
    }

    @objc func localIncreaseContrastToggled(_ sender: NSSwitch) {
        guard let r = selected, isLocalSimulator(r) || r.isSwiftCodeRemote else { return }
        let enabled = sender.state == .on
        Task { [weak self] in
            try? await DeviceHubSimulatorInstaller.setIncreaseContrast(udid: r.identifier, enabled: enabled)
            await MainActor.run { self?.canvas.showBanner("Increase Contrast: \(enabled ? "On" : "Off")", seconds: 2) }
        }
    }

    @objc func localReduceMotionToggled(_ sender: NSSwitch) {
        guard let r = selected, isLocalSimulator(r) || r.isSwiftCodeRemote else { return }
        let enabled = sender.state == .on
        Task { [weak self] in
            try? await DeviceHubSimulatorInstaller.setReduceMotion(udid: r.identifier, enabled: enabled)
            await MainActor.run { self?.canvas.showBanner("Reduce Motion: \(enabled ? "On" : "Off")", seconds: 2) }
        }
    }

    @objc func localStageManagerToggled(_ sender: NSSwitch) {
        guard let r = selected, isLocalSimulator(r) || r.isSwiftCodeRemote else { return }
        let enabled = sender.state == .on
        Task { [weak self] in
            try? await DeviceHubSimulatorInstaller.setStageManager(udid: r.identifier, enabled: enabled)
            await MainActor.run { self?.canvas.showBanner("Stage Manager: \(enabled ? "Enabled" : "Disabled")", seconds: 2) }
        }
    }

    

    struct HubReportFile: Identifiable {
        let id = UUID()
        let name: String
        let url: URL
        let modified: Date?
    }

    
    
    
    func diagnosticReports(for r: DeviceRow) -> [HubReportFile] {
        let fm = FileManager.default
        var out: [HubReportFile] = []
        let diagDir = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/DiagnosticReports")
        let exts: Set<String> = ["ips", "crash", "diag", "hang", "spin"]
        if let names = try? fm.contentsOfDirectory(atPath: diagDir.path) {
            for name in names where exts.contains((name as NSString).pathExtension.lowercased()) {
                let url = diagDir.appendingPathComponent(name)
                var hit = name.contains(r.identifier) || name.localizedCaseInsensitiveContains(r.name)
                if !hit, let head = try? String(contentsOf: url, encoding: .utf8).prefix(64 * 1024) {
                    hit = head.contains(r.identifier)
                }
                if hit {
                    let attrs = try? fm.attributesOfItem(atPath: url.path)
                    out.append(HubReportFile(name: name, url: url, modified: attrs?[.modificationDate] as? Date))
                }
            }
        }
        let simLogDir = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/CoreSimulator/\(r.identifier)")
        if let names = try? fm.contentsOfDirectory(atPath: simLogDir.path) {
            for name in names {
                let url = simLogDir.appendingPathComponent(name)
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue else { continue }
                let attrs = try? fm.attributesOfItem(atPath: url.path)
                out.append(HubReportFile(name: "CoreSimulator/\(name)", url: url, modified: attrs?[.modificationDate] as? Date))
            }
        }
        return out.sorted { ($0.modified ?? .distantPast) > ($1.modified ?? .distantPast) }
    }

    
    
    func commandHistory(for r: DeviceRow, limit: Int = 8) async -> [CommandExecutionRecord] {
        let history = await CommandExecutionEngine.shared.getHistory()
        return history.filter { record in
            record.command.arguments.contains(r.identifier)
        }.prefix(limit).map { $0 }
    }

    func buildReportsTab() {
        guard let r = selected else {
            inspectorContent.addArrangedSubview(Self.secondary("No Selection"))
            return
        }
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Self.cardSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false

        if isLocalSimulator(r) {
            buildLocalReports(into: stack, r: r)
        } else if isConnectPeer(r) {
            buildConnectReports(into: stack, r: r)
        } else {
            
            
            let note = InspectorCard(message: "Crash and diagnostic reports for “\(r.name)” are collected by macOS under ~/Library/Logs/DiagnosticReports. SwiftCode’s own command history below lists every simctl/devicectl call made for this device.",
                                     identifier: "reports-note")
            stack.addArrangedSubview(note)
            let open = NSButton(title: "Open DiagnosticReports Folder", target: self, action: #selector(openReportsFolderChosen(_:)))
            open.bezelStyle = .push
            open.controlSize = .small
            stack.addArrangedSubview(open)
            Task { [weak self] in
                let records = await self?.commandHistory(for: r, limit: 10) ?? []
                self?.appendCommandHistory(records, into: stack, tag: r.identifier)
            }
        }
        inspectorContent.addArrangedSubview(stack)
        stack.widthAnchor.constraint(equalTo: inspectorContent.widthAnchor, constant: -20).isActive = true
    }

    private func buildLocalReports(into stack: NSStackView, r: DeviceRow) {
        let reports = diagnosticReports(for: r)
        if reports.isEmpty {
            stack.addArrangedSubview(InspectorCard(message: "No Diagnostic Reports", identifier: "reports-empty"))
        } else {
            var rows: [InspectorCard.Row] = []
            for report in reports.prefix(8) {
                let b = NSButton(title: "Reveal", target: self, action: #selector(revealReportChosen(_:)))
                b.bezelStyle = .inline
                b.controlSize = .small
                b.identifier = .init(report.url.path)
                b.setAccessibilityLabel("Reveal \(report.name)")
                let when = report.modified.map { Self.reportDate.string(from: $0) } ?? ""
                rows.append(InspectorCard.Row(symbol: "exclamationmark.triangle",
                                              title: report.name + (when.isEmpty ? "" : " — \(when)"),
                                              control: b))
            }
            stack.addArrangedSubview(InspectorCard(rows: rows, identifier: "reports-list"))
        }
        let collect = NSButton(title: "Collect Diagnostics…", target: self, action: #selector(collectDiagnosticsChosen(_:)))
        collect.bezelStyle = .push
        collect.controlSize = .small
        collect.identifier = .init(r.identifier)
        stack.addArrangedSubview(collect)
        let open = NSButton(title: "Open Reports Folder", target: self, action: #selector(openReportsFolderChosen(_:)))
        open.bezelStyle = .push
        open.controlSize = .small
        stack.addArrangedSubview(open)
        Task { [weak self] in
            let records = await self?.commandHistory(for: r, limit: 10) ?? []
            self?.appendCommandHistory(records, into: stack, tag: r.identifier)
        }
    }

    private func buildConnectReports(into stack: NSStackView, r: DeviceRow) {
        guard let peer = connectPeers[r.identifier] else { return }
        let state = "Connection: \(peer.stateText)\nEndpoint: \(peer.device.host):\(peer.device.port)"
        stack.addArrangedSubview(InspectorCard(message: state + (peer.lastError.map { "\n\n\($0)" } ?? ""),
                                              identifier: "reports-connect"))
        let logs = NSButton(title: "View Device Logs", target: self, action: #selector(connectLogsChosen(_:)))
        logs.bezelStyle = .push
        logs.controlSize = .small
        logs.identifier = .init(r.identifier)
        stack.addArrangedSubview(logs)
        stack.addArrangedSubview(InspectorCard(message: "Log streaming uses the device’s logs.read permission. Request a sysdiagnose from the device itself for full diagnostics.",
                                              identifier: "reports-connect-note"))
    }

    static let reportDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    func appendCommandHistory(_ records: [CommandExecutionRecord], into stack: NSStackView, tag: String) {
        
        
        guard selected?.identifier == tag || tag.isEmpty else { return }
        guard !records.isEmpty else {
            stack.addArrangedSubview(InspectorCard(message: "No recorded commands for this device.", identifier: "reports-history-empty"))
            return
        }
        let lines = records.map { rec -> String in
            let cmd = ([rec.command.executableURL.lastPathComponent] + rec.command.arguments).joined(separator: " ")
            let when = Self.reportDate.string(from: rec.startedAt)
            let outcome = rec.exitCode == 0 ? "ok" : "exit \(rec.exitCode)"
            return "\(when)  \(outcome)  \(cmd)"
        }
        let text = NSTextField(wrappingLabelWithString: "Command History\n\n" + lines.joined(separator: "\n"))
        text.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        text.textColor = .secondaryLabelColor
        text.identifier = .init("reports-history")
        text.preferredMaxLayoutWidth = InspectorCard.width - 24
        stack.addArrangedSubview(text)
    }

    @objc func revealReportChosen(_ sender: NSButton) {
        guard let path = sender.identifier?.rawValue else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    @objc func openReportsFolderChosen(_ sender: Any?) {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/DiagnosticReports")
        NSWorkspace.shared.open(dir)
    }

    @objc func collectDiagnosticsChosen(_ sender: Any?) {
        guard let r = row(from: sender), isLocalSimulator(r) else { return }
        canvas.showBanner("Collecting diagnostics for “\(r.name)”…", seconds: 3)
        let captureDir = DeviceLiveSession.captureDirectory
        Task.detached { [weak self] in
            let dir = captureDir.appendingPathComponent("Diagnostics", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let result = DeviceHubSimctl.collectLogs(udid: r.identifier, minutes: 60, into: dir)
            await MainActor.run { [weak self] in
                guard let self else { return }
                if let archive = result.archive {
                    self.canvas.showBanner("Diagnostics saved: \(archive.lastPathComponent)", seconds: 4)
                    NSWorkspace.shared.activateFileViewerSelecting([archive])
                } else {
                    self.canvas.showBanner("Diagnostics failed: \(result.output.isEmpty ? "no output" : result.output)", seconds: 6)
                }
            }
        }
    }

    

    struct HubProfile: Identifiable {
        let id = UUID()
        let name: String
        let team: String
        let uuid: String
        let expiry: Date?
        let deviceCount: Int
        let appID: String
        let url: URL
    }

    
    
    static var profileCache: (profiles: [HubProfile], at: Date)?

    static func provisioningProfiles() -> [HubProfile] {
        if let c = profileCache, Date().timeIntervalSince(c.at) < 60 { return c.profiles }
        let fm = FileManager.default
        var out: [HubProfile] = []
        let dirs = [
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/MobileDevice/Provisioning Profiles"),
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Developer/Xcode/UserData/Provisioning Profiles"),
        ]
        for dir in dirs {
            guard let names = try? fm.contentsOfDirectory(atPath: dir.path) else { continue }
            for name in names where name.hasSuffix(".mobileprovision") {
                let url = dir.appendingPathComponent(name)
                let (status, output) = DeviceHubSimctl.runTool("/usr/bin/security", ["cms", "-D", "-i", url.path])
                guard status == 0,
                      let data = output.data(using: .utf8),
                      let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
                else { continue }
                let entitlements = plist["Entitlements"] as? [String: Any] ?? [:]
                let devices = plist["ProvisionedDevices"] as? [String] ?? []
                let expiry = (plist["ExpirationDate"] as? Date) ?? (plist["ExpirationDate"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }
                out.append(HubProfile(
                    name: plist["Name"] as? String ?? name,
                    team: plist["TeamName"] as? String ?? (entitlements["com.apple.developer.team-identifier"] as? String) ?? "",
                    uuid: plist["UUID"] as? String ?? "",
                    expiry: expiry,
                    deviceCount: devices.count,
                    appID: entitlements["application-identifier"] as? String ?? "",
                    url: url))
            }
        }
        out.sort { ($0.expiry ?? .distantFuture) < ($1.expiry ?? .distantFuture) }
        profileCache = (out, Date())
        return out
    }

    func buildProfilesTab() {
        guard let r = selected else {
            inspectorContent.addArrangedSubview(Self.secondary("No Selection"))
            return
        }
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Self.cardSpacing

        if isLocalSimulator(r) {
            stack.addArrangedSubview(InspectorCard(
                message: "Simulators are not code-signed and do not use provisioning profiles. The profiles below are the ones installed on this Mac for physical devices.",
                identifier: "profiles-sim-note"))
        }
        let profiles = Self.provisioningProfiles()
        if profiles.isEmpty {
            stack.addArrangedSubview(InspectorCard(message: "No Provisioning Profiles", identifier: "profiles-empty"))
        } else {
            var rows: [InspectorCard.Row] = []
            for p in profiles.prefix(10) {
                let b = NSButton(title: "Reveal", target: self, action: #selector(revealProfileChosen(_:)))
                b.bezelStyle = .inline
                b.controlSize = .small
                b.identifier = .init(p.url.path)
                b.setAccessibilityLabel("Reveal \(p.name)")
                var title = p.name
                if !p.team.isEmpty { title += " — \(p.team)" }
                if let e = p.expiry { title += " · expires \(Self.reportDate.string(from: e))" }
                if p.deviceCount > 0 { title += " · \(p.deviceCount) devices" }
                rows.append(InspectorCard.Row(symbol: "checkmark.seal", title: title, control: b))
            }
            stack.addArrangedSubview(InspectorCard(rows: rows, identifier: "profiles-list"))
        }
        inspectorContent.addArrangedSubview(stack)
        stack.widthAnchor.constraint(equalTo: inspectorContent.widthAnchor, constant: -20).isActive = true
    }

    @objc func revealProfileChosen(_ sender: NSButton) {
        guard let path = sender.identifier?.rawValue else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }
}



@MainActor
final class DeviceHubLogWindowController: NSWindowController {
    private let textView = NSTextView()
    private var process: Process?
    private var pipe: Pipe?
    private var peer: HubConnectPeer?
    private var streamUDID: String?
    private var tail = ""
    private var didClose = false

    init(title: String, udid: String?, peer: HubConnectPeer?) {
        self.streamUDID = udid
        self.peer = peer
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        textView.isEditable = false
        textView.isRichText = false
        textView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.string = "Starting log stream…\n"
        scroll.documentView = textView
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 480),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.title = title
        window.contentView = scroll
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func start() {
        if let udid = streamUDID {
            guard let (p, pipe) = DeviceHubSimctl.streamLogs(udid: udid) else {
                append("Could not start `simctl spawn \(udid) log stream`.")
                return
            }
            process = p
            self.pipe = pipe
            pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty, let self else { return }
                let text = String(decoding: data, as: UTF8.self)
                Task { @MainActor in self.append(text) }
            }
        } else if let peer {
            peer.onLogLine = { [weak self] line in self?.append(line + "\n") }
            Task { await peer.subscribeLogs() }
        }
    }

    private func append(_ text: String) {
        tail += text
        
        if tail.count > 512 * 1024 { tail = String(tail.suffix(256 * 1024)) }
        textView.string = tail
        
        let end = NSRange(location: max(0, (textView.string as NSString).length - 1), length: 0)
        textView.scrollRangeToVisible(end)
    }

    override func close() {
        guard !didClose else { return }
        didClose = true
        if let p = process, p.isRunning { p.terminate() }
        process = nil
        pipe?.fileHandleForReading.readabilityHandler = nil
        pipe = nil
        Task { await peer?.unsubscribeLogs() }
        peer?.onLogLine = nil
        super.close()
    }
}

extension DeviceHubLogWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) { close() }
}
#endif
