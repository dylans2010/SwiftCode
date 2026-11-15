import Foundation
import Testing
@testable import YcodeDeviceModel
@testable import YcodeIDECore

@Suite struct DeviceDiscoveryServiceTests {
    static let simctl = """
    {"devicetypes": [{"identifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-17", "name": "iPhone 17"}],
     "runtimes": [{"identifier": "com.apple.CoreSimulator.SimRuntime.iOS-27-1", "version": "27.1", "buildversion": "23A123", "supportedArchitectures": ["arm64"]},
                  {"identifier": "com.apple.CoreSimulator.SimRuntime.xrOS-26-0", "version": "26.0"}],
     "devices": {"com.apple.CoreSimulator.SimRuntime.iOS-27-1": [
        {"name": "iPhone 17", "udid": "U1", "state": "Booted", "isAvailable": true,
         "deviceTypeIdentifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-17"}],
       "com.apple.CoreSimulator.SimRuntime.xrOS-26-0": [
        {"name": "Vision Pro", "udid": "U2", "state": "Shutdown", "isAvailable": true}],
       "com.apple.CoreSimulator.SimRuntime.Foo-1-0": [{"name": "Mystery", "udid": "U3"}]}}
    """

    static let devicectl = """
    {"result": {"devices": [
      {"identifier": "AAA",
       "deviceProperties": {"name": "Phone", "osVersionNumber": "26.1", "buildVersion": "23B55"},
       "hardwareProperties": {"platform": "iOS", "reality": "physical", "marketingName": "iPhone 17", "cpuType": "arm64e", "udid": "AAA"},
       "connectionProperties": {"pairingState": "paired", "tunnelState": "connected"}},
      {"identifier": "BBB",
       "deviceProperties": {"name": "Odd"},
       "hardwareProperties": {"platform": "NewOS", "reality": "physical"},
       "connectionProperties": {}}]}}
    """

    @Test func simulatorsUseCanonicalPlatformAndRealFields() {
        let rows = DevicesList.simulators(simctlJSON: Data(Self.simctl.utf8))
        #expect(rows.count == 2)
        #expect(rows[0].name == "iPhone 17")
        #expect(rows[0].platform == "iOS")
        #expect(rows[0].osVersion == "27.1")
        #expect(rows[0].model == "iPhone 17")
        #expect(rows[0].state == "Booted")
        #expect(rows[0].architecture == "arm64")
        #expect(rows[0].buildVersion == "23A123")
        #expect(rows[1].name == "Vision Pro")
        #expect(rows[1].platform == "visionOS")
        #expect(rows[1].osVersion == "26.0")
    }

    @Test func simulatorRowsFromDiscoveryResultMatchSimctlJSON() throws {
        let response = try JSONDecoder().decode(SimctlListResponse.self, from: Data(Self.simctl.utf8))
        let result = SimctlDiscoveryResult(
            runtimes: response.runtimes ?? [],
            devices: response.devices ?? [:],
            deviceTypes: response.devicetypes ?? [],
            pairs: response.pairs ?? [:]
        )
        let rows = DevicesList.simulatorRows(from: result)
        #expect(rows.count == 2)
        #expect(rows.map(\.platform).sorted() == ["iOS", "visionOS"])
        #expect(rows.first { $0.identifier == "U1" }?.architecture == "arm64")
        #expect(rows.first { $0.identifier == "U1" }?.buildVersion == "23A123")
        #expect(rows.first { $0.identifier == "U2" }?.architecture == nil)
    }

    @Test func physicalDevicesSurfaceUnknownPlatformInsteadOfDefaultingiOS() throws {
        let rows = try DevicesList.parsePhysicalDevices(data: Data(Self.devicectl.utf8))
        #expect(rows.count == 2)
        #expect(rows[0].name == "Odd")
        #expect(rows[0].platform == "Unknown")
        #expect(rows[1].name == "Phone")
        #expect(rows[1].platform == "iOS")
        #expect(rows[1].osVersion == "26.1")
        #expect(rows[1].buildVersion == "23B55")
        #expect(rows[1].architecture == "arm64e")
        #expect(rows[1].state == "paired, connected")
    }

    @Test func physicalDeviceParsingThrowsOnBadOutput() {
        #expect(throws: DeviceDiscoveryError.self) {
            try DevicesList.parsePhysicalDevices(data: Data("not json".utf8))
        }
        #expect(throws: DeviceDiscoveryError.self) {
            try DevicesList.parsePhysicalDevices(data: Data("{\"result\": {}}".utf8))
        }
        #expect(DevicesList.devices(devicectlJSON: Data("not json".utf8)).isEmpty)
    }

    @Test func shutDownSwiftCodeSimulatorHasNoFabricatedOSVersion() {
        let row = DeviceRow.shutDownSwiftCodeSimulator(name: "Phone (SwiftCode)", identifier: "probe-1")
        #expect(row.osVersion.isEmpty)
        #expect(row.platform == "iOS")
        #expect(row.state == "Shutdown")
    }

    @Test func simctlServiceParsesCanonicalPlatformsAndArchitectures() async throws {
        let json = """
        {"runtimes": [{"identifier": "com.apple.CoreSimulator.SimRuntime.iOS-18-0", "name": "iOS 18.0", "version": "18.0", "isAvailable": true, "supportedArchitectures": ["arm64"]},
                      {"identifier": "com.apple.CoreSimulator.SimRuntime.xrOS-2-0", "name": "xrOS 2.0", "version": "2.0", "isAvailable": true},
                      {"identifier": "com.apple.CoreSimulator.SimRuntime.Foo-1-0", "name": "Foo 1.0", "version": "1.0", "isAvailable": true}],
         "devices": {"com.apple.CoreSimulator.SimRuntime.iOS-18-0": [{"name": "iPhone", "udid": "U1", "state": "Booted", "isAvailable": true}],
                     "com.apple.CoreSimulator.SimRuntime.xrOS-2-0": [{"name": "Vision", "udid": "U2", "state": "Shutdown", "isAvailable": true}],
                     "com.apple.CoreSimulator.SimRuntime.Foo-1-0": [{"name": "Mystery", "udid": "U3", "state": "Shutdown", "isAvailable": true}]}}
        """
        let parsed = try await SimctlService().parseDevicesAndRuntimes(data: Data(json.utf8))
        #expect(parsed.devices.count == 3)
        let iphone = parsed.devices.first { $0.udid == "U1" }
        #expect(iphone?.platform == "iOS")
        #expect(iphone?.osVersion == "18.0")
        #expect(iphone?.architecture == "arm64")
        let vision = parsed.devices.first { $0.udid == "U2" }
        #expect(vision?.platform == "visionOS")
        #expect(vision?.osVersion == "2.0")
        #expect(vision?.architecture == "Unknown")
        let mystery = parsed.devices.first { $0.udid == "U3" }
        #expect(mystery?.platform == "Unknown")
        #expect(mystery?.osVersion == "1.0")
        #expect(parsed.runtimes.map(\.platform).sorted() == ["Unknown", "iOS", "visionOS"])
    }
}
