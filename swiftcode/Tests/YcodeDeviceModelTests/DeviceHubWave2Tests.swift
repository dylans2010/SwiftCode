#if os(macOS)
import Foundation
import Testing
@testable import YcodeDeviceModel

@Suite struct DeviceHubWave2Tests {
    private func testDefaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "device-hub-wave2-\(UUID().uuidString)"))
    }

    @Test func groupRoundTripPersistsThroughStore() throws {
        let defaults = try testDefaults()
        let store = DeviceGroupStore(defaults: defaults)
        let created = try #require(store.createGroup(name: "Test Rig"))
        #expect(store.loadGroups() == [created])
        let again = DeviceGroupStore(defaults: defaults)
        #expect(again.loadGroups().count == 1)
        #expect(again.loadGroups()[0].name == "Test Rig")
    }

    @Test func groupEncodeDecodeRoundTrip() throws {
        let group = DeviceGroup(name: "Evening", deviceIDs: ["udid-1", "udid-2"])
        let data = try #require(DeviceGroupStore.encodeGroups([group]))
        let decoded = DeviceGroupStore.decodeGroups(from: data)
        #expect(decoded == [group])
    }

    @Test func groupDecodeRejectsBadData() {
        #expect(DeviceGroupStore.decodeGroups(from: Data("not json".utf8)).isEmpty)
        #expect(DeviceGroupStore.decodeGroups(from: nil).isEmpty)
        #expect(DeviceGroupStore.decodeGroups(from: Data()) .isEmpty)
    }

    @Test func groupDuplicateNameRefused() throws {
        let store = DeviceGroupStore(defaults: try testDefaults())
        #expect(store.createGroup(name: "Rig") != nil)
        #expect(store.createGroup(name: "rig") == nil)
        #expect(store.createGroup(name: "   ") == nil)
        #expect(store.loadGroups().count == 1)
    }

    @Test func groupMembershipAddRemoveRoundTrip() throws {
        let store = DeviceGroupStore(defaults: try testDefaults())
        let group = try #require(store.createGroup(name: "Rig"))
        #expect(store.addDevice("udid-1", toGroup: group.id) == true)
        #expect(store.addDevice("udid-1", toGroup: group.id) == false)
        #expect(store.loadGroups()[0].deviceIDs == ["udid-1"])
        #expect(store.groupsContaining(deviceID: "udid-1").count == 1)
        #expect(store.removeDevice("udid-1", fromGroup: group.id) == true)
        #expect(store.removeDevice("udid-1", fromGroup: group.id) == false)
        #expect(store.loadGroups()[0].deviceIDs.isEmpty)
    }

    @Test func groupRenameAndDelete() throws {
        let store = DeviceGroupStore(defaults: try testDefaults())
        let first = try #require(store.createGroup(name: "Old"))
        let second = try #require(store.createGroup(name: "Other"))
        #expect(store.renameGroup(id: first.id, name: "Other") == false)
        #expect(store.renameGroup(id: first.id, name: "New") == true)
        #expect(store.loadGroups().first { $0.id == first.id }?.name == "New")
        #expect(store.renameGroup(id: UUID(), name: "Nope") == false)
        #expect(store.deleteGroup(id: second.id) == true)
        #expect(store.deleteGroup(id: second.id) == false)
        #expect(store.loadGroups().count == 1)
    }

    @Test func groupPruneDropsMissingDevices() throws {
        let store = DeviceGroupStore(defaults: try testDefaults())
        let group = try #require(store.createGroup(name: "Rig"))
        #expect(store.addDevice("gone", toGroup: group.id) == true)
        #expect(store.addDevice("kept", toGroup: group.id) == true)
        let pruned = store.pruneMissingDevices(knownIDs: ["kept"])
        #expect(pruned[0].deviceIDs == ["kept"])
        #expect(store.loadGroups()[0].deviceIDs == ["kept"])
    }

    @Test func preferredDevicesRoundTrip() throws {
        let store = DeviceGroupStore(defaults: try testDefaults())
        store.markPreferred("udid-1")
        store.markPreferred("udid-2")
        store.markPreferred("udid-1")
        #expect(store.preferredDeviceIDs() == ["udid-1", "udid-2"])
        #expect(store.isPreferred("udid-2") == true)
        store.unmarkPreferred("udid-1")
        #expect(store.preferredDeviceIDs() == ["udid-2"])
    }

    @Test func simulatorSelectionRoundTrip() throws {
        let store = DeviceGroupStore(defaults: try testDefaults())
        #expect(store.savedSimulatorSelection() == nil)
        store.saveSimulatorSelection("udid-9")
        #expect(store.savedSimulatorSelection() == "udid-9")
        store.saveSimulatorSelection(nil)
        #expect(store.savedSimulatorSelection() == nil)
    }

    @Test func groupOperationResultSummary() {
        let ok = DeviceGroupOperationResult(succeededIDs: ["a", "b"])
        #expect(ok.allSucceeded == true)
        #expect(ok.summary == "2 devices updated")
        let partial = DeviceGroupOperationResult(
            succeededIDs: ["a"],
            failures: [DeviceGroupOperationFailure(deviceID: "b", error: "boot did not complete")])
        #expect(partial.allSucceeded == false)
        #expect(partial.summary.contains("1 updated, 1 failed"))
    }

    @Test func runtimeBrowserParsesSimctlRuntimes() {
        let json = """
        {"runtimes": [
            {"identifier": "com.apple.CoreSimulator.SimRuntime.iOS-27-0", "name": "iOS 27.0", "version": "27.0", "buildversion": "23A123", "isAvailable": true, "supportedDeviceTypes": ["com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro"]},
            {"identifier": "com.apple.CoreSimulator.SimRuntime.watchOS-12-0", "name": "watchOS 12.0", "version": "12.0", "isAvailable": false},
            {"identifier": "com.apple.CoreSimulator.SimRuntime.Foo-1-0", "name": "Foo 1.0", "version": "1.0", "isAvailable": true}
        ]}
        """
        let entries = DeviceHubRuntimeEntry.parseRuntimesJSON(Data(json.utf8))
        #expect(entries.count == 2)
        #expect(entries[0].platform == .iOS)
        #expect(entries[0].buildVersion == "23A123")
        #expect(entries[0].supportedDeviceTypes == ["com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro"])
        #expect(entries[1].platform == .watchOS)
        #expect(entries[1].isAvailable == false)
    }

    @Test func runtimeBrowserParsesBadJSONAsEmpty() {
        #expect(DeviceHubRuntimeEntry.parseRuntimesJSON(Data("nope".utf8)).isEmpty)
        #expect(DeviceHubRuntimeEntry.parseRuntimesJSON(Data("{}".utf8)).isEmpty)
    }

    @Test func runtimeSizeDisplayIsUnknownWithoutMeasurement() {
        let entry = DeviceHubRuntimeEntry(identifier: "com.apple.CoreSimulator.SimRuntime.iOS-27-0", name: "iOS 27.0", version: "27.0", platform: .iOS)
        #expect(entry.sizeDisplay == "unknown")
        #expect(entry.sizeBytes == nil)
    }

    @Test func runtimeSizeDisplayFormatsMeasuredBytes() {
        let entry = DeviceHubRuntimeEntry(identifier: "com.apple.CoreSimulator.SimRuntime.iOS-27-0", name: "iOS 27.0", version: "27.0", platform: .iOS, sizeBytes: 8_589_934_592)
        #expect(entry.sizeDisplay != "unknown")
        #expect(entry.sizeDisplay.contains("GB"))
    }

    @Test func runtimeDirectorySizeMeasuresRealFiles() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("device-hub-size-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("blob.bin")
        try Data(repeating: 7, count: 4096).write(to: file)
        #expect(DeviceHubRuntimeEntry.directorySize(atPath: dir.path) == 4096)
        #expect(DeviceHubRuntimeEntry.directorySize(atPath: dir.appendingPathComponent("missing").path) == nil)
        try? FileManager.default.removeItem(at: dir)
    }

    @Test func runtimeBrowserMergesDiskPaths() {
        let entry = DeviceHubRuntimeEntry(identifier: "com.apple.CoreSimulator.SimRuntime.iOS-27-0", name: "iOS 27.0", version: "27.0", platform: .iOS)
        let merged = DeviceHubRuntimeEntry.merged(
            simctlEntries: [entry],
            diskPaths: ["com.apple.CoreSimulator.SimRuntime.iOS-27-0": "/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS 27.0.simruntime"])
        #expect(merged[0].path == "/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS 27.0.simruntime")
        #expect(merged[0].sizeDisplay == "unknown")
    }

    @Test func runtimeBrowserErrorMessagesAreActionable() {
        #expect(DeviceHubRuntimeBrowserError.listFailed("xcrun: error").errorDescription?.contains("xcrun") == true)
        #expect(DeviceHubRuntimeBrowserError.removeFailed("").errorDescription?.contains("Removing") == true)
        #expect(DeviceHubRuntimeBrowserError.runtimeNotFound("abc").errorDescription?.contains("abc") == true)
    }

    @Test func hubSectionsCoverNavigation() {
        #expect(DeviceHubSection.allCases.count == 8)
        #expect(DeviceHubSection.overview.title == "Overview")
        #expect(DeviceHubSection.devices.showsCanvas == true)
        #expect(DeviceHubSection.simulators.showsCanvas == true)
        #expect(DeviceHubSection.platforms.showsCanvas == false)
        #expect(DeviceHubSection.runtimes.showsCanvas == false)
        #expect(DeviceHubSection.groups.showsCanvas == false)
        #expect(DeviceHubSection.diagnostics.showsCanvas == false)
        #expect(DeviceHubSection.settings.showsCanvas == false)
        #expect(DeviceHubSection(rawValue: "Runtimes") == .runtimes)
        #expect(DeviceHubSection(rawValue: "Nope") == nil)
    }

    @Test func overviewSnapshotToolchainSummary() {
        let unscanned = DeviceHubOverviewSnapshot.empty
        #expect(unscanned.toolchainHealthy == false)
        #expect(unscanned.toolchainSummary.contains("not been scanned"))
        #expect(unscanned.xcodeDisplay == "Not installed")
        #expect(unscanned.developerDirectoryDisplay == "Unknown")
        let missing = DeviceHubOverviewSnapshot(isXcodeInstalled: false, hasScanned: true)
        #expect(missing.toolchainSummary.contains("not installed"))
        let cltOnly = DeviceHubOverviewSnapshot(isXcodeInstalled: true, isCommandLineToolsOnly: true, hasScanned: true)
        #expect(cltOnly.toolchainSummary.contains("Command Line Tools"))
        #expect(cltOnly.toolchainHealthy == false)
        let healthy = DeviceHubOverviewSnapshot(
            xcodeVersion: "27.1", xcodeBuild: "27A123",
            developerDirectory: "/Applications/Xcode.app/Contents/Developer", isXcodeInstalled: true, hasScanned: true)
        #expect(healthy.toolchainHealthy == true)
        #expect(healthy.xcodeDisplay == "Xcode 27.1 (27A123)")
        #expect(healthy.developerDirectoryDisplay == "/Applications/Xcode.app/Contents/Developer")
    }

    @Test func pipelineFailureReportsDetectedReadiness() {
        let readiness = PhysicalDeviceReadiness.untrusted(udid: "udid-1", reason: "pairing prompt not answered")
        let report = DiagnosticsFormatter.formatPipelineFailure(stage: .installingApplication, error: "install failed", readiness: readiness)
        #expect(report.contains("Not trusted"))
        #expect(report.contains("Trust This Computer"))
        #expect(report.contains("install failed"))
        #expect(report.contains("Detected Device State"))
        #expect(report.contains("Verify developer mode is active") == false)
    }

    @Test func pipelineFailureWithReadyDeviceSaysSo() {
        let readiness = PhysicalDeviceReadiness(udid: "udid-1", trust: .trusted, developerMode: .enabled, connectionState: "connected")
        let report = DiagnosticsFormatter.formatPipelineFailure(stage: .buildingProject, error: "build failed", readiness: readiness)
        #expect(report.contains("Trusted, Developer Mode on"))
        #expect(report.contains("do not explain this failure"))
    }

    @Test func pipelineFailureWithoutProbeSaysSo() {
        let report = DiagnosticsFormatter.formatPipelineFailure(stage: .launchingApplication, error: "launch failed")
        #expect(report.contains("was not probed"))
        #expect(report.contains("launch failed"))
    }

    @Test func markingDisconnectedMakesDeviceUnavailable() {
        let device = ConnectedDevice(name: "Phone", model: "iPhone", productType: "iPhone17,1", platform: "iOS",
                                     osVersion: "27.0", buildVersion: "23A123", architecture: "arm64", udid: "udid-1")
        #expect(device.isAvailable == true)
        let gone = device.markingDisconnected()
        #expect(gone.isAvailable == false)
        #expect(gone.isConnected == false)
        #expect(gone.isOffline == true)
        #expect(gone.name == "Phone")
        #expect(gone.udid == "udid-1")
    }

    @Test func sidebarGroupSectionsListMembers() {
        var model = HubSidebarModel(devices: [
            HubDevice(id: "a", name: "Phone A", platform: "iOS", osVersion: "27.0", family: .phone, isSimulator: true, isRunning: false),
            HubDevice(id: "b", name: "Phone B", platform: "iOS", osVersion: "27.0", family: .phone, isSimulator: true, isRunning: true),
        ])
        model.groups = [DeviceGroup(name: "Rig", deviceIDs: ["a", "missing"])]
        #expect(model.groupSections.count == 1)
        #expect(model.groupSections[0].title == "Group: Rig")
        #expect(model.groupSections[0].devices.map(\.id) == ["a"])
        #expect(model.rowsIncludingGroups.contains { if case .header("Group: Rig", collapsed: false) = $0 { return true } else { return false } })
        #expect(model.rowsIncludingGroups.contains { $0.device?.id == "a" })
    }

    @Test func sidebarGroupSectionsHideWhenEmpty() {
        var model = HubSidebarModel(devices: [
            HubDevice(id: "a", name: "Phone A", platform: "iOS", osVersion: "27.0", family: .phone, isSimulator: true, isRunning: false),
        ])
        model.groups = [DeviceGroup(name: "Empty", deviceIDs: [])]
        #expect(model.groupSections.isEmpty)
    }
}
#endif
