import Foundation
import Testing
@testable import YcodeDeviceModel

@Suite struct DeviceDiscoveryTests {
    @Test func devicePlatformMapsRuntimeIdentifiers() {
        #expect(DevicePlatform(runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.iOS-27-1") == .iOS)
        #expect(DevicePlatform(runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.xrOS-26-0") == .visionOS)
        #expect(DevicePlatform(runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.watchOS-12-0") == .watchOS)
        #expect(DevicePlatform(runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.tvOS-26-0") == .tvOS)
        #expect(DevicePlatform(runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.macOS-26-0") == .macOS)
        #expect(DevicePlatform(runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.Foo-1-0") == .unknown)
    }

    @Test func devicePlatformParsesDisplayNames() {
        #expect(DevicePlatform(parsing: "iOS") == .iOS)
        #expect(DevicePlatform(parsing: "iPadOS") == .iPadOS)
        #expect(DevicePlatform(parsing: "visionOS") == .visionOS)
        #expect(DevicePlatform(parsing: "xrOS") == .visionOS)
        #expect(DevicePlatform(parsing: "watchOS") == .watchOS)
        #expect(DevicePlatform(parsing: "tvOS") == .tvOS)
        #expect(DevicePlatform(parsing: "macOS") == .macOS)
        #expect(DevicePlatform(parsing: nil) == .unknown)
        #expect(DevicePlatform(parsing: "Something Else") == .unknown)
        #expect(DevicePlatform.unknown.rawValue == "Unknown")
    }

    @Test func deviceParserSurfacesUnknownFields() {
        let json = """
        [{"name": "Mystery Phone", "identifier": "UDID-1"}]
        """
        let devices = DeviceParser.parseXCDeviceList(json)
        #expect(devices.count == 1)
        #expect(devices[0].platform == "Unknown")
        #expect(devices[0].osVersion == "Unknown")
        #expect(devices[0].buildVersion == "Unknown")
        #expect(devices[0].architecture == "Unknown")
        #expect(devices[0].isDeveloperModeEnabled == nil)
        #expect(devices[0].isTrusted == nil)
        #expect(devices[0].isDeploymentSupported == nil)
        #expect(devices[0].isSigningCompatible == nil)
    }

    @Test func deviceParserKeepsRealFieldsWhenPresent() {
        let json = """
        [{"name": "Dylan's iPhone", "model": "iPhone 17 Pro", "platform": "iOS",
          "operatingSystemVersion": "26.1", "buildVersion": "23A123", "architecture": "arm64e",
          "identifier": "UDID-2", "modelUTI": "com.apple.iphone-17-pro",
          "isWirelesslyConnected": true, "isConnected": true, "isAvailable": true}]
        """
        let devices = DeviceParser.parseXCDeviceList(json)
        #expect(devices.count == 1)
        #expect(devices[0].buildVersion == "23A123")
        #expect(devices[0].architecture == "arm64e")
        #expect(devices[0].platform == "iOS")
        #expect(devices[0].isWireless)
    }

    @Test func connectedDeviceUnknownsDefaultToNil() {
        let device = ConnectedDevice(name: "X", model: "X", productType: "X", platform: "iOS", osVersion: "1", buildVersion: "1", architecture: "arm64", udid: "U")
        #expect(device.isDeveloperModeEnabled == nil)
        #expect(device.isTrusted == nil)
        #expect(device.isDeploymentSupported == nil)
        #expect(device.isSigningCompatible == nil)
    }

    @Test func deviceInfoDetailsParsesDevicectlJSON() throws {
        let json = """
        {"result": {"devices": [
          {"identifier": "UDID-1",
           "deviceProperties": {"name": "Dylan's iPhone", "osVersionNumber": "26.1", "buildVersion": "23A123", "developerMode": true},
           "hardwareProperties": {"platform": "iOS", "marketingName": "iPhone 17 Pro", "cpuType": "arm64e", "udid": "UDID-1"},
           "connectionProperties": {"pairingState": "paired", "tunnelState": "connected"}}]}}
        """
        let details = try DeviceInfoDetails.parse(data: Data(json.utf8), deviceUDID: "UDID-1")
        #expect(details.identifier == "UDID-1")
        #expect(details.name == "Dylan's iPhone")
        #expect(details.platform == "iOS")
        #expect(details.osVersion == "26.1")
        #expect(details.buildVersion == "23A123")
        #expect(details.architecture == "arm64e")
        #expect(details.model == "iPhone 17 Pro")
        #expect(details.developerModeEnabled == true)
        #expect(details.trusted == true)
        #expect(details.connectionState == "paired, connected")
    }

    @Test func deviceInfoDetailsParsesResultObjectShape() throws {
        let json = """
        {"result": {"deviceProperties": {"name": "Watch"},
           "hardwareProperties": {"platform": "watchOS"},
           "connectionProperties": {}}}
        """
        let details = try DeviceInfoDetails.parse(data: Data(json.utf8), deviceUDID: "UDID-9")
        #expect(details.identifier == "UDID-9")
        #expect(details.name == "Watch")
        #expect(details.platform == "watchOS")
        #expect(details.buildVersion == nil)
        #expect(details.architecture == nil)
        #expect(details.developerModeEnabled == nil)
        #expect(details.trusted == nil)
    }

    @Test func deviceInfoDetailsThrowsOnBadOutput() {
        #expect(throws: DeviceInfoDetails.ParsingError.self) {
            try DeviceInfoDetails.parse(data: Data("not json".utf8), deviceUDID: "UDID-1")
        }
        #expect(throws: DeviceInfoDetails.ParsingError.self) {
            try DeviceInfoDetails.parse(data: Data("{\"result\": {}}".utf8), deviceUDID: "UDID-1")
        }
    }

    @Test func runnerRunsEcho() async throws {
        let result = try await DeviceConnectProcessRunner.shared.run(
            executableURL: URL(fileURLWithPath: "/bin/echo"),
            arguments: ["hello"]
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "hello")
    }

    @Test func runnerBlockingEcho() throws {
        let result = try DeviceConnectProcessRunner.shared.runBlocking(
            executableURL: URL(fileURLWithPath: "/bin/echo"),
            arguments: ["blocking"]
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("blocking"))
    }

    @Test func runnerRejectsMissingExecutable() async {
        do {
            _ = try await DeviceConnectProcessRunner.shared.run(
                executableURL: URL(fileURLWithPath: "/nonexistent/tool"),
                arguments: []
            )
            Issue.record("Expected an executableNotFound error.")
        } catch let error as DeviceConnectProcessError {
            guard case .executableNotFound = error else {
                Issue.record("Expected executableNotFound, got \(error).")
                return
            }
        } catch {
            Issue.record("Unexpected error: \(error).")
        }
    }

    @Test func runnerRejectsInvalidArguments() async {
        do {
            _ = try await DeviceConnectProcessRunner.shared.run(
                executableURL: URL(fileURLWithPath: "/bin/echo"),
                arguments: ["a\0b"]
            )
            Issue.record("Expected an invalidArguments error.")
        } catch let error as DeviceConnectProcessError {
            guard case .invalidArguments = error else {
                Issue.record("Expected invalidArguments, got \(error).")
                return
            }
        } catch {
            Issue.record("Unexpected error: \(error).")
        }
        do {
            let url = try #require(URL(string: "echo"))
            _ = try await DeviceConnectProcessRunner.shared.run(
                executableURL: url,
                arguments: []
            )
            Issue.record("Expected an invalidArguments error for a non-file executable URL.")
        } catch let error as DeviceConnectProcessError {
            guard case .invalidArguments = error else {
                Issue.record("Expected invalidArguments, got \(error).")
                return
            }
        } catch {
            Issue.record("Unexpected error: \(error).")
        }
    }

    @Test func runnerTimesOut() async {
        do {
            _ = try await DeviceConnectProcessRunner.shared.run(
                executableURL: URL(fileURLWithPath: "/bin/sleep"),
                arguments: ["30"],
                timeout: 0.5
            )
            Issue.record("Expected a timedOut error.")
        } catch let error as DeviceConnectProcessError {
            guard case .timedOut = error else {
                Issue.record("Expected timedOut, got \(error).")
                return
            }
        } catch {
            Issue.record("Unexpected error: \(error).")
        }
    }
}
