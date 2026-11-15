import Foundation
import Testing
@testable import YcodeIDECore

@Suite struct DeviceUtilitiesTests {
    @Test func validatedURLAcceptsHTTPS() throws {
        let url = try DeviceUtilities.validatedURL("https:example.com/path")
        #expect(url.scheme == "https")
    }

    @Test func validatedURLAcceptsCustomScheme() throws {
        let url = try DeviceUtilities.validatedURL("myapp:open")
        #expect(url.scheme == "myapp")
    }

    @Test func validatedURLRejectsEmptyAndSchemeLess() {
        #expect(throws: DeviceUtilitiesError.self) { try DeviceUtilities.validatedURL("") }
        #expect(throws: DeviceUtilitiesError.self) { try DeviceUtilities.validatedURL("   ") }
        #expect(throws: DeviceUtilitiesError.self) { try DeviceUtilities.validatedURL("example.com/no-scheme") }
        #expect(throws: DeviceUtilitiesError.self) { try DeviceUtilities.validatedURL("my app:open") }
    }

    @Test func openURLArgumentsBuildExactCommand() throws {
        let url = try DeviceUtilities.validatedURL("myapp:open")
        #expect(DeviceUtilities.openURLArguments(udid: "booted", url: url) == ["simctl", "openurl", "booted", "myapp:open"])
    }

    @Test func validatedDeviceIdentifierAcceptsBootedAndTrims() throws {
        #expect(try DeviceUtilities.validatedDeviceIdentifier("booted") == "booted")
        #expect(try DeviceUtilities.validatedDeviceIdentifier("  4F19A097-DAE2-4298-99EB-23D4F2DBAF97  ") == "4F19A097-DAE2-4298-99EB-23D4F2DBAF97")
    }

    @Test func validatedDeviceIdentifierRejectsEmpty() {
        #expect(throws: DeviceUtilitiesError.self) { try DeviceUtilities.validatedDeviceIdentifier("") }
        #expect(throws: DeviceUtilitiesError.self) { try DeviceUtilities.validatedDeviceIdentifier("   ") }
    }

    @Test func validatedBundleIDAcceptsReverseDNS() throws {
        #expect(try DeviceUtilities.validatedBundleID("com.example.app") == "com.example.app")
        #expect(try DeviceUtilities.validatedBundleID("com.apple.DocumentsApp") == "com.apple.DocumentsApp")
    }

    @Test func validatedBundleIDRejectsInvalid() {
        #expect(throws: DeviceUtilitiesError.self) { try DeviceUtilities.validatedBundleID("") }
        #expect(throws: DeviceUtilitiesError.self) { try DeviceUtilities.validatedBundleID("singlecomponent") }
        #expect(throws: DeviceUtilitiesError.self) { try DeviceUtilities.validatedBundleID("com.example app") }
        #expect(throws: DeviceUtilitiesError.self) { try DeviceUtilities.validatedBundleID(".com.example") }
        #expect(throws: DeviceUtilitiesError.self) { try DeviceUtilities.validatedBundleID("com..example") }
        #expect(throws: DeviceUtilitiesError.self) { try DeviceUtilities.validatedBundleID("com.example/app") }
    }

    @Test func pushArgumentsIncludeBundleIDWhenGiven() {
        #expect(DeviceUtilities.pushArguments(udid: "booted", bundleID: "com.example.app", payloadPath: "/tmp/payload.apns") == ["simctl", "push", "booted", "com.example.app", "/tmp/payload.apns"])
    }

    @Test func pushArgumentsOmitBundleIDWhenNil() {
        #expect(DeviceUtilities.pushArguments(udid: "booted", bundleID: nil, payloadPath: "/tmp/payload.apns") == ["simctl", "push", "booted", "/tmp/payload.apns"])
    }

    @Test func validatedPushPayloadAcceptsValid() throws {
        let withTarget = Data("{\"Simulator Target Bundle\": \"com.example.app\", \"aps\": {\"alert\": \"hi\"}}".utf8)
        try DeviceUtilities.validatedPushPayload(withTarget, bundleID: nil)
        let withArgument = Data("{\"aps\": {\"alert\": \"hi\"}}".utf8)
        try DeviceUtilities.validatedPushPayload(withArgument, bundleID: "com.example.app")
    }

    @Test func validatedPushPayloadRejectsMissingAps() {
        let data = Data("{\"Simulator Target Bundle\": \"com.example.app\"}".utf8)
        #expect(throws: DeviceUtilitiesError.self) { try DeviceUtilities.validatedPushPayload(data, bundleID: nil) }
    }

    @Test func validatedPushPayloadRejectsInvalidJSON() {
        let data = Data("not json".utf8)
        #expect(throws: DeviceUtilitiesError.self) { try DeviceUtilities.validatedPushPayload(data, bundleID: "com.example.app") }
        let array = Data("[1, 2, 3]".utf8)
        #expect(throws: DeviceUtilitiesError.self) { try DeviceUtilities.validatedPushPayload(array, bundleID: "com.example.app") }
    }

    @Test func validatedPushPayloadRejectsOversized() {
        let padding = String(repeating: "x", count: 5000)
        let data = Data("{\"aps\": {\"alert\": \"\(padding)\"}}".utf8)
        #expect(data.count > DeviceUtilities.maximumPushPayloadBytes)
        #expect(throws: DeviceUtilitiesError.self) { try DeviceUtilities.validatedPushPayload(data, bundleID: "com.example.app") }
    }

    @Test func validatedPushPayloadRequiresTargetBundleWhenBundleIDNil() {
        let withoutTarget = Data("{\"aps\": {\"alert\": \"hi\"}}".utf8)
        #expect(throws: DeviceUtilitiesError.self) { try DeviceUtilities.validatedPushPayload(withoutTarget, bundleID: nil) }
    }

    @Test func appContainerArgumentsBuildExactCommand() {
        #expect(DeviceUtilities.appContainerArguments(udid: "booted", bundleID: "com.example.app") == ["simctl", "get_app_container", "booted", "com.example.app", "data"])
    }

    @Test func parsedContainerPathTrimsAndRejectsGarbage() throws {
        let parsed = try DeviceUtilities.parsedContainerPath("/Users/dylan/Library/Developer/CoreSimulator/Devices/ABC/data/Containers/Data/Application/DEF\n")
        #expect(parsed == "/Users/dylan/Library/Developer/CoreSimulator/Devices/ABC/data/Containers/Data/Application/DEF")
        #expect(throws: DeviceUtilitiesError.self) { try DeviceUtilities.parsedContainerPath("") }
        #expect(throws: DeviceUtilitiesError.self) { try DeviceUtilities.parsedContainerPath("relative/path") }
    }

    @Test func containerDocumentsPathRejectsTraversal() throws {
        let path = try DeviceUtilities.containerDocumentsPath(containerPath: "/container", fileName: "report.json")
        #expect(path == "/container/Documents/report.json")
        #expect(throws: DeviceUtilitiesError.self) { try DeviceUtilities.containerDocumentsPath(containerPath: "/container", fileName: "../escape.json") }
        #expect(throws: DeviceUtilitiesError.self) { try DeviceUtilities.containerDocumentsPath(containerPath: "/container", fileName: "sub/report.json") }
        #expect(throws: DeviceUtilitiesError.self) { try DeviceUtilities.containerDocumentsPath(containerPath: "/container", fileName: "") }
    }

    @Test func containerFilePathRejectsAbsoluteAndTraversal() throws {
        let path = try DeviceUtilities.containerFilePath(containerPath: "/container", relativePath: "Documents/report.json")
        #expect(path == "/container/Documents/report.json")
        #expect(throws: DeviceUtilitiesError.self) { try DeviceUtilities.containerFilePath(containerPath: "/container", relativePath: "/etc/passwd") }
        #expect(throws: DeviceUtilitiesError.self) { try DeviceUtilities.containerFilePath(containerPath: "/container", relativePath: "Documents/../escape.json") }
        #expect(throws: DeviceUtilitiesError.self) { try DeviceUtilities.containerFilePath(containerPath: "/container", relativePath: "") }
    }

    @Test func samplePushPayloadIsValidAndWithinLimit() throws {
        let text = DeviceUtilities.samplePushPayload(bundleID: "com.example.app")
        let data = Data(text.utf8)
        #expect(data.count <= DeviceUtilities.maximumPushPayloadBytes)
        try DeviceUtilities.validatedPushPayload(data, bundleID: "com.example.app")
        let object = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        #expect(object?["Simulator Target Bundle"] as? String == "com.example.app")
        #expect(object?["aps"] != nil)
    }

    @Test func orientationSupportIsUnsupported() {
        guard case .unsupported(let reason) = DeviceUtilities.orientationSupport else {
            Issue.record("Orientation should report unsupported.")
            return
        }
        #expect(reason == DeviceUtilities.orientationUnavailableReason)
        #expect(!reason.isEmpty)
    }

    @Test func setOrientationThrowsUnsupported() async {
        var threwUnsupported = false
        do {
            try await DeviceUtilities().setOrientation(.landscapeLeft, udid: "booted")
        } catch let error as DeviceUtilitiesError {
            if case .orientationUnsupported = error {
                threwUnsupported = true
            }
        } catch {
            Issue.record("Unexpected error: \(error.localizedDescription)")
        }
        #expect(threwUnsupported)
    }
}
