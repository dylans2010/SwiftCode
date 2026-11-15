#if os(macOS)
import AppKit
import SwiftUI
import YcodeDeviceModel
import YcodeIDECore

extension DevicesController {

    public func makeSectionPopup() -> NSPopUpButton {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.addItems(withTitles: DeviceHubSection.allCases.map(\.title))
        popup.selectItem(at: DeviceHubSection.allCases.firstIndex(of: hubSection) ?? 0)
        popup.target = self
        popup.action = #selector(hubSectionChosen(_:))
        popup.setAccessibilityLabel("Hub section")
        return popup
    }

    @objc public func hubSectionChosen(_ sender: NSPopUpButton) {
        guard let section = sender.selectedItem.map({ DeviceHubSection(rawValue: $0.title) ?? .devices }) else { return }
        showHubSection(section)
    }

    public func showHubSection(_ section: DeviceHubSection) {
        hubSection = section
        defaults.set(section.rawValue, forKey: DeviceHubStoreKeys.section)
        sectionPopup?.selectItem(at: DeviceHubSection.allCases.firstIndex(of: section) ?? 0)
        if section.showsCanvas {
            setFilter(section == .simulators ? .simulators : .physical)
            sectionHosting?.view.isHidden = true
            updateWorkspaceViews()
            return
        }
        if sectionHosting == nil {
            let hosting = NSHostingController(rootView: AnyView(sectionPageView(section)))
            hosting.view.translatesAutoresizingMaskIntoConstraints = false
            workspaceContainer.addSubview(hosting.view)
            NSLayoutConstraint.activate([
                hosting.view.topAnchor.constraint(equalTo: workspaceContainer.topAnchor),
                hosting.view.leadingAnchor.constraint(equalTo: workspaceContainer.leadingAnchor),
                hosting.view.trailingAnchor.constraint(equalTo: workspaceContainer.trailingAnchor),
                hosting.view.bottomAnchor.constraint(equalTo: workspaceContainer.bottomAnchor),
            ])
            sectionHosting = hosting
        } else {
            sectionHosting?.rootView = AnyView(sectionPageView(section))
        }
        updateWorkspaceViews()
    }

    public func refreshHubSectionPage() {
        guard !hubSection.showsCanvas else { return }
        sectionHosting?.rootView = AnyView(sectionPageView(hubSection))
    }

    private func sectionPageView(_ section: DeviceHubSection) -> some View {
        switch section {
        case .overview:
            return AnyView(DeviceHubOverviewView(snapshot: overviewSnapshot(), onRefresh: { [weak self] in
                Task {
                    await PlatformManager.shared.refresh()
                    await MainActor.run { self?.refreshHubSectionPage() }
                }
            }))
        case .platforms:
            return AnyView(DeviceHubPlatformsView(snapshot: PlatformManager.shared.snapshot))
        case .runtimes:
            return AnyView(DeviceHubRuntimeBrowserView())
        case .groups:
            return AnyView(DeviceHubGroupsView(hub: self))
        case .diagnostics:
            return AnyView(DeviceHubDiagnosticsView(snapshot: PlatformManager.shared.snapshot))
        case .settings:
            return AnyView(DeviceHubSettingsView(hub: self))
        case .devices, .simulators:
            return AnyView(EmptyView())
        }
    }

    public func overviewSnapshot() -> DeviceHubOverviewSnapshot {
        let catalog = PlatformManager.shared.snapshot
        let installed = catalog.installedPlatforms.map { $0.platform.rawValue }
        let missing = catalog.missingPlatforms.map { $0.platform.rawValue }
        let runtimes = SimulatorManager.shared.runtimes
        return DeviceHubOverviewSnapshot(
            connectedPhysicalDevices: devices.filter(\.isAvailable).count,
            availableSimulators: simulators.filter(\.isAvailable).count,
            bootedSimulators: simulators.filter { $0.state == "Booted" }.count,
            installedPlatforms: installed,
            missingPlatforms: missing,
            installedRuntimes: runtimes.count,
            availableRuntimes: runtimes.filter(\.isAvailable).count,
            xcodeVersion: catalog.xcodeVersion,
            xcodeBuild: catalog.xcodeBuild,
            developerDirectory: catalog.developerDirectory,
            isXcodeInstalled: catalog.isXcodeInstalled,
            isCommandLineToolsOnly: catalog.isCommandLineToolsOnly,
            hasScanned: catalog.hasScanned,
            lastError: PlatformManager.shared.lastError?.localizedDescription ?? catalog.discoveryError,
            globalIssues: catalog.globalIssues.map(\.message)
        )
    }

    @discardableResult
    public func bootGroup(_ group: DeviceGroup) -> Task<Void, Never>? {
        let task = Task { [weak self] in
            guard let self else { return }
            var result = DeviceGroupOperationResult()
            for id in group.deviceIDs {
                guard let row = self.allRows.first(where: { $0.identifier == id }) else {
                    result.failures.append(DeviceGroupOperationFailure(deviceID: id, error: "device no longer exists"))
                    continue
                }
                guard self.isLocalSimulator(row) else {
                    result.failures.append(DeviceGroupOperationFailure(deviceID: row.name, error: "not a local simulator"))
                    continue
                }
                if row.state == "Booted" {
                    result.succeededIDs.append(row.name)
                    continue
                }
                SimulatorManager.shared.selectedDeviceID = id
                await SimulatorManager.shared.bootSelectedDevice()
                let state = SimulatorManager.shared.devices.first(where: { $0.udid == id })?.state
                if state == .booted || state == .ready {
                    result.succeededIDs.append(row.name)
                } else {
                    result.failures.append(DeviceGroupOperationFailure(deviceID: row.name, error: "boot did not complete (state: \(state?.rawValue ?? "unknown"))"))
                }
            }
            await MainActor.run {
                self.refreshLocalRows()
                if result.allSucceeded {
                    self.canvas.showBanner("“\(group.name)” booted: \(result.summary)", seconds: 3)
                } else {
                    let detail = result.failures.map { "\($0.deviceID): \($0.error)" }.joined(separator: "; ")
                    self.canvas.showBanner("“\(group.name)” boot incomplete. \(detail)", seconds: 6)
                }
            }
        }
        return task
    }

    @discardableResult
    public func shutDownGroup(_ group: DeviceGroup) -> Task<Void, Never>? {
        let task = Task { [weak self] in
            guard let self else { return }
            var result = DeviceGroupOperationResult()
            for id in group.deviceIDs {
                guard let row = self.allRows.first(where: { $0.identifier == id }) else {
                    result.failures.append(DeviceGroupOperationFailure(deviceID: id, error: "device no longer exists"))
                    continue
                }
                guard self.isLocalSimulator(row) else {
                    result.failures.append(DeviceGroupOperationFailure(deviceID: row.name, error: "not a local simulator"))
                    continue
                }
                if row.state != "Booted" {
                    result.succeededIDs.append(row.name)
                    continue
                }
                SimulatorManager.shared.selectedDeviceID = id
                await SimulatorManager.shared.shutdownSelectedDevice()
                let state = SimulatorManager.shared.devices.first(where: { $0.udid == id })?.state
                if state == .shutdown {
                    result.succeededIDs.append(row.name)
                } else {
                    result.failures.append(DeviceGroupOperationFailure(deviceID: row.name, error: "shut down did not complete (state: \(state?.rawValue ?? "unknown"))"))
                }
            }
            await MainActor.run {
                self.refreshLocalRows()
                if result.allSucceeded {
                    self.canvas.showBanner("“\(group.name)” shut down: \(result.summary)", seconds: 3)
                } else {
                    let detail = result.failures.map { "\($0.deviceID): \($0.error)" }.joined(separator: "; ")
                    self.canvas.showBanner("“\(group.name)” shut down incomplete. \(detail)", seconds: 6)
                }
            }
        }
        return task
    }

    @objc public func showUtilitiesChosen(_ sender: Any?) {
        guard let r = row(from: sender) ?? selected else { return }
        showUtilities(for: r)
    }

    public func showUtilities(for r: DeviceRow) {
        guard let window = view.window else { return }
        let target: DeviceUtilitiesTarget
        if isLocalSimulator(r) {
            if let device = SimulatorManager.shared.devices.first(where: { $0.udid == r.identifier }) {
                target = .simulator(device)
            } else {
                let state: SimulatorState = r.state == "Booted" ? .booted : .shutdown
                target = .simulator(SimulatorDevice(
                    udid: r.identifier, name: r.name, runtimeIdentifier: r.deviceTypeID ?? "",
                    platform: r.platform, osVersion: r.osVersion, architecture: r.architecture ?? "",
                    state: state, isAvailable: r.isAvailable))
            }
        } else {
            target = .physicalDevice(name: r.name)
        }
        let hosting = NSHostingController(rootView: DeviceHubUtilitiesView(target: target))
        let sheetWindow = NSWindow(contentViewController: hosting)
        sheetWindow.styleMask = [.titled, .closable, .resizable]
        sheetWindow.title = "Device Utilities — \(r.name)"
        sheetWindow.setContentSize(NSSize(width: 560, height: 640))
        window.beginSheet(sheetWindow)
    }

    @objc public func newWatchSimulatorChosen(_ sender: Any?) {
        showCreateSimulatorSheet(initialPlatform: .watchOS)
    }

    @objc public func newVisionSimulatorChosen(_ sender: Any?) {
        showCreateSimulatorSheet(initialPlatform: .visionOS)
    }
}
#endif
