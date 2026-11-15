import Foundation
import Testing
import YcodeIDECore
import YcodePreviews

@Suite struct SimctlCoreTests {
    @Test func decodesSimctlListResponse() throws {
        let json = """
        {
          "runtimes": [
            {
              "identifier": "com.apple.CoreSimulator.SimRuntime.iOS-18-2",
              "name": "iOS 18.2",
              "version": "18.2",
              "buildversion": "22C146",
              "platform": "iOS",
              "isAvailable": true
            }
          ],
          "devices": {
            "com.apple.CoreSimulator.SimRuntime.iOS-18-2": [
              {
                "udid": "A1B2C3D4-1111-2222-3333-444455556666",
                "name": "iPhone 16 Pro",
                "state": "Booted",
                "isAvailable": true
              }
            ]
          },
          "devicetypes": [
            {
              "identifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro",
              "name": "iPhone 16 Pro",
              "productFamily": "iPhone"
            }
          ]
        }
        """
        let response = try JSONDecoder().decode(SimctlListResponse.self, from: Data(json.utf8))
        #expect(response.runtimes?.count == 1)
        #expect(response.runtimes?.first?.name == "iOS 18.2")
        let devices = response.devices?["com.apple.CoreSimulator.SimRuntime.iOS-18-2"]
        #expect(devices?.count == 1)
        #expect(devices?.first?.name == "iPhone 16 Pro")
        #expect(devices?.first?.state == "Booted")
        #expect(devices?.first?.isAvailable == true)
    }

    @Test func simulatorStateIsRunning() {
        #expect(SimulatorState.booted.isRunning)
        #expect(SimulatorState.booting.isRunning)
        #expect(SimulatorState.ready.isRunning)
        #expect(!SimulatorState.shutdown.isRunning)
        #expect(!SimulatorState.failed.isRunning)
        #expect(!SimulatorState.unknown.isRunning)
    }

    @Test func snapshotFindsOrphanedDevices() {
        let runtime = SimulatorRuntime(
            identifier: "com.apple.CoreSimulator.SimRuntime.iOS-18-2",
            name: "iOS 18.2",
            version: "18.2",
            platform: "iOS"
        )
        let matched = SimulatorDevice(
            udid: "11111111-1111-1111-1111-111111111111",
            name: "iPhone 16 Pro",
            runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.iOS-18-2",
            platform: "iOS",
            osVersion: "18.2",
            architecture: "arm64",
            state: .booted
        )
        let orphaned = SimulatorDevice(
            udid: "22222222-2222-2222-2222-222222222222",
            name: "iPhone 15",
            runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.iOS-17-5",
            platform: "iOS",
            osVersion: "17.5",
            architecture: "arm64",
            state: .shutdown
        )
        let snapshot = SimulatorSnapshot(
            runtimes: [runtime],
            devices: [matched, orphaned],
            bootedDeviceIDs: ["11111111-1111-1111-1111-111111111111"],
            generatedAt: Date(),
            discoveryDuration: .seconds(1)
        )
        #expect(snapshot.orphanedDevices.count == 1)
        #expect(snapshot.orphanedDevices.first?.udid == "22222222-2222-2222-2222-222222222222")
    }

    @Test func previewSandboxPolicyBlocksSystemPaths() {
        let project = URL(fileURLWithPath: "/tmp/SwiftCodeTestProject")
        let policy = PreviewSandbox().makePolicy(projectDirectory: project)
        #expect(policy.projectDirectory == project)
        #expect(policy.allowNetwork == false)
        #expect(policy.blockedPaths.contains("/System"))
        #expect(policy.blockedPaths.contains("/private"))
    }

    @Test func simulatorRebootCommandConstruction() {
        let cmd = SimulatorCommand.reboot(udid: "A1B2C3D4-5678-90AB-CDEF-1234567890AB")
        #expect(cmd.arguments == ["simctl", "reboot", "A1B2C3D4-5678-90AB-CDEF-1234567890AB"])
        #expect(cmd.executable == "/usr/bin/xcrun")
    }

    @Test func simulatorNotifyPostCommandConstruction() {
        let cmd = SimulatorCommand.notifyPost(udid: "A1B2C3D4-5678-90AB-CDEF-1234567890AB", notification: "com.apple.UIKit.SimulatorPreferences.ShakeDevice")
        #expect(cmd.arguments == ["simctl", "notify_post", "A1B2C3D4-5678-90AB-CDEF-1234567890AB", "com.apple.UIKit.SimulatorPreferences.ShakeDevice"])
    }

    @Test func listAppsCommandConstruction() {
        let cmd = SimulatorCommand.listApps(udid: "A1B2C3D4-5678-90AB-CDEF-1234567890AB")
        #expect(cmd.arguments == ["simctl", "listapps", "A1B2C3D4-5678-90AB-CDEF-1234567890AB"])
        #expect(cmd.executable == "/usr/bin/xcrun")
    }

    @Test func cloneCommandConstruction() {
        let cmd = SimulatorCommand.clone(udid: "A1B2C3D4-5678-90AB-CDEF-1234567890AB", name: "Cloned iPhone")
        #expect(cmd.arguments == ["simctl", "clone", "A1B2C3D4-5678-90AB-CDEF-1234567890AB", "Cloned iPhone"])
        #expect(cmd.executable == "/usr/bin/xcrun")
    }

    @Test func recordVideoCommandConstruction() {
        let cmd = SimulatorCommand.recordVideo(udid: "A1B2C3D4-5678-90AB-CDEF-1234567890AB", path: "/tmp/recording.mov")
        #expect(cmd.arguments == ["simctl", "io", "A1B2C3D4-5678-90AB-CDEF-1234567890AB", "recordVideo", "--codec=h264", "/tmp/recording.mov"])
        #expect(cmd.executable == "/usr/bin/xcrun")
    }

    @Test func screenshotCommandConstruction() {
        let cmd = SimulatorCommand.screenshot(udid: "A1B2C3D4-5678-90AB-CDEF-1234567890AB", path: "/tmp/shot.png")
        #expect(cmd.arguments == ["simctl", "io", "A1B2C3D4-5678-90AB-CDEF-1234567890AB", "screenshot", "/tmp/shot.png"])
        #expect(cmd.executable == "/usr/bin/xcrun")
    }

    @Test func parsesListAppsPlist() async throws {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>com.apple.Preferences</key>
            <dict>
                <key>CFBundleDisplayName</key>
                <string>Settings</string>
                <key>CFBundleName</key>
                <string>Preferences</string>
                <key>CFBundleShortVersionString</key>
                <string>1.0</string>
                <key>CFBundleVersion</key>
                <string>1</string>
                <key>Path</key>
                <string>/Applications/Preferences.app</string>
            </dict>
            <key>com.example.TestApp</key>
            <dict>
                <key>CFBundleName</key>
                <string>TestApp</string>
                <key>CFBundleVersion</key>
                <string>42</string>
                <key>Path</key>
                <string>/tmp/TestApp.app</string>
            </dict>
        </dict>
        </plist>
        """
        let service = SimctlService()
        let apps = try await service.parseInstalledApplications(data: Data(plist.utf8), platform: "iOS")
        #expect(apps.count == 2)
        #expect(apps[0].bundleIdentifier == "com.apple.Preferences")
        #expect(apps[0].name == "Settings")
        #expect(apps[0].path == "/Applications/Preferences.app")
        #expect(apps[0].version == "1.0")
        #expect(apps[0].targetPlatform == "iOS")
        #expect(apps[1].bundleIdentifier == "com.example.TestApp")
        #expect(apps[1].name == "TestApp")
        #expect(apps[1].version == "42")
    }

    @Test func parsesEmptyListAppsPlist() async throws {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0">
        <dict>
        </dict>
        </plist>
        """
        let service = SimctlService()
        let apps = try await service.parseInstalledApplications(data: Data(plist.utf8), platform: "iOS")
        #expect(apps.isEmpty)
    }

    @Test func parseListAppsRejectsInvalidPlist() async {
        let service = SimctlService()
        #expect(throws: SimulatorError.self) {
            try await service.parseInstalledApplications(data: Data("not a plist".utf8), platform: "iOS")
        }
    }

    @Test func parseListAppsSkipsMalformedRecords() async throws {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0">
        <dict>
            <key>com.example.Good</key>
            <dict>
                <key>CFBundleDisplayName</key>
                <string>Good App</string>
                <key>Path</key>
                <string>/tmp/Good.app</string>
            </dict>
            <key>com.example.Broken</key>
            <string>not a dictionary</string>
            <key></key>
            <dict>
                <key>CFBundleDisplayName</key>
                <string>Nameless</string>
            </dict>
        </dict>
        </plist>
        """
        let service = SimctlService()
        let apps = try await service.parseInstalledApplications(data: Data(plist.utf8), platform: "iOS")
        #expect(apps.count == 1)
        #expect(apps[0].bundleIdentifier == "com.example.Good")
        #expect(apps[0].name == "Good App")
        #expect(apps[0].version == "")
    }

    @Test func writeDeviceNameRoundTrip() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("swiftcode-rename-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let plistURL = dir.appendingPathComponent("device.plist")
        let original: [String: Any] = [
            "UDID": "A1B2C3D4-5678-90AB-CDEF-1234567890AB",
            "name": "Old Name",
            "runtime": "com.apple.CoreSimulator.SimRuntime.iOS-18-2"
        ]
        let originalData = try PropertyListSerialization.data(fromPropertyList: original, format: .xml, options: 0)
        try originalData.write(to: plistURL)
        let verified = try SimulatorManager.writeDeviceName(plistURL: plistURL, name: "New Name")
        #expect(verified == "New Name")
        let rereadData = try Data(contentsOf: plistURL)
        let reread = try PropertyListSerialization.propertyList(from: rereadData, options: [], format: nil) as? [String: Any]
        #expect(reread?["name"] as? String == "New Name")
        #expect(reread?["UDID"] as? String == "A1B2C3D4-5678-90AB-CDEF-1234567890AB")
        #expect(reread?["runtime"] as? String == "com.apple.CoreSimulator.SimRuntime.iOS-18-2")
    }

    @Test func writeDeviceNameRejectsEmptyName() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("swiftcode-rename-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let plistURL = dir.appendingPathComponent("device.plist")
        let originalData = try PropertyListSerialization.data(fromPropertyList: ["name": "Old Name"], format: .xml, options: 0)
        try originalData.write(to: plistURL)
        #expect(throws: SimulatorError.self) {
            try SimulatorManager.writeDeviceName(plistURL: plistURL, name: "   ")
        }
    }

    @Test func writeDeviceNameRejectsMissingPlist() {
        let plistURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("swiftcode-rename-test-\(UUID().uuidString)/device.plist")
        #expect(throws: SimulatorError.self) {
            try SimulatorManager.writeDeviceName(plistURL: plistURL, name: "New Name")
        }
    }
}

