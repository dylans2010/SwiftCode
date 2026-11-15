#if os(macOS)
import Foundation
import Testing
@testable import YcodeUI

@Suite struct DeviceHubCreateValidationTests {
    private func deviceType(name: String, identifier: String, productFamily: String) -> DeviceTypeRecord {
        DeviceTypeRecord(name: name, identifier: identifier, productFamily: productFamily)
    }

    private func iphone() -> DeviceTypeRecord {
        deviceType(name: "iPhone 17 Pro", identifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro", productFamily: "iPhone")
    }

    private func ipad() -> DeviceTypeRecord {
        deviceType(name: "iPad Pro 13-inch (M5)", identifier: "com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5", productFamily: "iPad")
    }

    private func watch() -> DeviceTypeRecord {
        deviceType(name: "Apple Watch Series 10 (46mm)", identifier: "com.apple.CoreSimulator.SimDeviceType.Apple-Watch-Series-10-46mm", productFamily: "Apple Watch")
    }

    private func tv() -> DeviceTypeRecord {
        deviceType(name: "Apple TV 4K (3rd generation)", identifier: "com.apple.CoreSimulator.SimDeviceType.Apple-TV-4K-3rd-generation", productFamily: "Apple TV")
    }

    private func vision() -> DeviceTypeRecord {
        deviceType(name: "Apple Vision Pro", identifier: "com.apple.CoreSimulator.SimDeviceType.Apple-Vision-Pro", productFamily: "Apple Vision")
    }

    @Test func runtimeFamilyReadsIOSFromIdentifier() {
        #expect(SimulatorCreateValidation.runtimeFamily(identifier: "com.apple.CoreSimulator.SimRuntime.iOS-27-0", name: "iOS 27.0") == "iOS")
    }

    @Test func runtimeFamilyReadsWatchOSFromIdentifier() {
        #expect(SimulatorCreateValidation.runtimeFamily(identifier: "com.apple.CoreSimulator.SimRuntime.watchOS-11-0", name: "watchOS 11.0") == "watchOS")
    }

    @Test func runtimeFamilyReadsTvOSFromIdentifier() {
        #expect(SimulatorCreateValidation.runtimeFamily(identifier: "com.apple.CoreSimulator.SimRuntime.tvOS-26-0", name: "tvOS 26.0") == "tvOS")
    }

    @Test func runtimeFamilyReadsVisionOSFromXrOSIdentifier() {
        #expect(SimulatorCreateValidation.runtimeFamily(identifier: "com.apple.CoreSimulator.SimRuntime.xrOS-2-0", name: "visionOS 2.0") == "visionOS")
    }

    @Test func runtimeFamilyFallsBackToRuntimeName() {
        #expect(SimulatorCreateValidation.runtimeFamily(identifier: "com.example.CustomRuntime", name: "visionOS 2.0") == "visionOS")
    }

    @Test func runtimeFamilyReturnsNilForUnknownRuntime() {
        #expect(SimulatorCreateValidation.runtimeFamily(identifier: "com.example.CustomRuntime", name: "Custom Runtime 1.0") == nil)
    }

    @Test func expectedRuntimeFamilyMapsProductFamilies() {
        #expect(SimulatorCreateValidation.expectedRuntimeFamily(productFamily: "iPhone") == "iOS")
        #expect(SimulatorCreateValidation.expectedRuntimeFamily(productFamily: "iPad") == "iOS")
        #expect(SimulatorCreateValidation.expectedRuntimeFamily(productFamily: "Apple Watch") == "watchOS")
        #expect(SimulatorCreateValidation.expectedRuntimeFamily(productFamily: "Apple TV") == "tvOS")
        #expect(SimulatorCreateValidation.expectedRuntimeFamily(productFamily: "Apple Vision") == "visionOS")
    }

    @Test func expectedRuntimeFamilyReturnsNilForUnknownFamily() {
        #expect(SimulatorCreateValidation.expectedRuntimeFamily(productFamily: "Mac") == nil)
    }

    @Test func runtimeFamilyForPlatformCoversAllPlatforms() {
        #expect(SimulatorCreateValidation.runtimeFamily(for: .iOS) == "iOS")
        #expect(SimulatorCreateValidation.runtimeFamily(for: .iPadOS) == "iOS")
        #expect(SimulatorCreateValidation.runtimeFamily(for: .watchOS) == "watchOS")
        #expect(SimulatorCreateValidation.runtimeFamily(for: .tvOS) == "tvOS")
        #expect(SimulatorCreateValidation.runtimeFamily(for: .visionOS) == "visionOS")
    }

    @Test func iphoneAcceptsIOSRuntime() {
        #expect(SimulatorCreateValidation.isCompatible(deviceType: iphone(), runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.iOS-27-0", runtimeName: "iOS 27.0"))
    }

    @Test func ipadAcceptsIOSRuntime() {
        #expect(SimulatorCreateValidation.isCompatible(deviceType: ipad(), runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.iOS-27-0", runtimeName: "iOS 27.0"))
    }

    @Test func iphoneRejectsWatchOSRuntime() {
        #expect(!SimulatorCreateValidation.isCompatible(deviceType: iphone(), runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.watchOS-11-0", runtimeName: "watchOS 11.0"))
    }

    @Test func watchAcceptsWatchOSRuntime() {
        #expect(SimulatorCreateValidation.isCompatible(deviceType: watch(), runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.watchOS-11-0", runtimeName: "watchOS 11.0"))
    }

    @Test func watchRejectsIOSRuntime() {
        #expect(!SimulatorCreateValidation.isCompatible(deviceType: watch(), runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.iOS-27-0", runtimeName: "iOS 27.0"))
    }

    @Test func visionAcceptsXrOSRuntime() {
        #expect(SimulatorCreateValidation.isCompatible(deviceType: vision(), runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.xrOS-2-0", runtimeName: "visionOS 2.0"))
    }

    @Test func visionRejectsIOSRuntime() {
        #expect(!SimulatorCreateValidation.isCompatible(deviceType: vision(), runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.iOS-27-0", runtimeName: "iOS 27.0"))
    }

    @Test func tvAcceptsTvOSRuntime() {
        #expect(SimulatorCreateValidation.isCompatible(deviceType: tv(), runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.tvOS-26-0", runtimeName: "tvOS 26.0"))
    }

    @Test func tvRejectsIOSRuntime() {
        #expect(!SimulatorCreateValidation.isCompatible(deviceType: tv(), runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.iOS-27-0", runtimeName: "iOS 27.0"))
    }

    @Test func unknownRuntimeIsIncompatible() {
        #expect(!SimulatorCreateValidation.isCompatible(deviceType: iphone(), runtimeIdentifier: "com.example.CustomRuntime", runtimeName: "Custom Runtime 1.0"))
    }

    @Test func validationErrorNamesBothSelectionsForIncompatiblePair() {
        let message = SimulatorCreateValidation.validationError(
            name: "My Watch",
            deviceType: watch(),
            runtimeName: "iOS 27.0",
            runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.iOS-27-0",
            existingNames: []
        )
        #expect(message?.contains("Apple Watch Series 10 (46mm)") == true)
        #expect(message?.contains("iOS 27.0") == true)
        #expect(message?.contains("watchOS") == true)
    }

    @Test func validationErrorForMissingDeviceType() {
        let message = SimulatorCreateValidation.validationError(
            name: "My Sim",
            deviceType: nil,
            runtimeName: "iOS 27.0",
            runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.iOS-27-0",
            existingNames: []
        )
        #expect(message?.contains("Select a device type and a runtime") == true)
    }

    @Test func validationErrorForMissingRuntime() {
        let message = SimulatorCreateValidation.validationError(
            name: "My Sim",
            deviceType: iphone(),
            runtimeName: nil,
            runtimeIdentifier: nil,
            existingNames: []
        )
        #expect(message?.contains("Select a device type and a runtime") == true)
    }

    @Test func validationErrorNamesExistingDeviceForDuplicateName() {
        let message = SimulatorCreateValidation.validationError(
            name: "iPhone 17 Pro",
            deviceType: iphone(),
            runtimeName: "iOS 27.0",
            runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.iOS-27-0",
            existingNames: ["iPhone 17 Pro", "iPad Pro 13-inch (M5)"]
        )
        #expect(message?.contains("iPhone 17 Pro") == true)
        #expect(message?.contains("already exists") == true)
    }

    @Test func validationErrorFindsDuplicateIgnoringCase() {
        let message = SimulatorCreateValidation.validationError(
            name: "iphone 17 pro",
            deviceType: iphone(),
            runtimeName: "iOS 27.0",
            runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.iOS-27-0",
            existingNames: ["iPhone 17 Pro"]
        )
        #expect(message?.contains("already exists") == true)
    }

    @Test func validationErrorFindsDuplicateIgnoringSurroundingWhitespace() {
        let message = SimulatorCreateValidation.validationError(
            name: "  iPhone 17 Pro  ",
            deviceType: iphone(),
            runtimeName: "iOS 27.0",
            runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.iOS-27-0",
            existingNames: ["iPhone 17 Pro"]
        )
        #expect(message?.contains("already exists") == true)
    }

    @Test func validationErrorPassesForUniqueName() {
        #expect(SimulatorCreateValidation.validationError(
            name: "My Test Phone",
            deviceType: iphone(),
            runtimeName: "iOS 27.0",
            runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.iOS-27-0",
            existingNames: ["iPhone 17 Pro"]
        ) == nil)
    }

    @Test func validationErrorPassesForCompatiblePairWithUniqueName() {
        #expect(SimulatorCreateValidation.validationError(
            name: "My Test Watch",
            deviceType: watch(),
            runtimeName: "watchOS 11.0",
            runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.watchOS-11-0",
            existingNames: ["Apple Watch Series 10 (46mm)"]
        ) == nil)
    }

    @Test func duplicateExistingNameReturnsNilForEmptyName() {
        #expect(SimulatorCreateValidation.duplicateExistingName("   ", existingNames: ["iPhone 17 Pro"]) == nil)
    }

    @Test func duplicateExistingNameReturnsStoredCasing() {
        #expect(SimulatorCreateValidation.duplicateExistingName("iphone 17 pro", existingNames: ["iPhone 17 Pro"]) == "iPhone 17 Pro")
    }

    @Test func parseExistingSimulatorNamesCollectsNamesAcrossRuntimes() {
        let data = Data("{\"devices\": {\"com.apple.CoreSimulator.SimRuntime.iOS-27-0\": [{\"name\": \"iPhone 17 Pro\", \"udid\": \"AAAAAAAA-0000-0000-0000-000000000001\"}, {\"name\": \"iPhone 17\", \"udid\": \"AAAAAAAA-0000-0000-0000-000000000002\"}], \"com.apple.CoreSimulator.SimRuntime.watchOS-11-0\": [{\"name\": \"Apple Watch Series 10 (46mm)\", \"udid\": \"AAAAAAAA-0000-0000-0000-000000000003\"}]}}".utf8)
        let names = DeviceHubSimulatorInstaller.parseExistingSimulatorNames(from: data)
        #expect(Set(names) == ["iPhone 17 Pro", "iPhone 17", "Apple Watch Series 10 (46mm)"])
    }

    @Test func parseExistingSimulatorNamesReturnsEmptyForEmptyDevices() {
        let data = Data("{\"devices\": {}}".utf8)
        #expect(DeviceHubSimulatorInstaller.parseExistingSimulatorNames(from: data).isEmpty)
    }

    @Test func parseExistingSimulatorNamesReturnsEmptyForMalformedJSON() {
        let data = Data("not json".utf8)
        #expect(DeviceHubSimulatorInstaller.parseExistingSimulatorNames(from: data).isEmpty)
    }

    @Test func parseExistingSimulatorNamesSkipsEntriesWithoutNames() {
        let data = Data("{\"devices\": {\"com.apple.CoreSimulator.SimRuntime.iOS-27-0\": [{\"udid\": \"AAAAAAAA-0000-0000-0000-000000000001\"}, {\"name\": \"iPhone 17 Pro\", \"udid\": \"AAAAAAAA-0000-0000-0000-000000000002\"}]}}".utf8)
        #expect(DeviceHubSimulatorInstaller.parseExistingSimulatorNames(from: data) == ["iPhone 17 Pro"])
    }

    private func versionedPhone(min: String? = nil, max: String? = nil) -> DeviceTypeRecord {
        DeviceTypeRecord(name: "iPhone 17 Pro", identifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro",
                         productFamily: "iPhone", minRuntimeVersion: min, maxRuntimeVersion: max)
    }

    private func iosRuntime(version: String, supported: [String] = []) -> RuntimeRecord {
        RuntimeRecord(name: "iOS \(version)", identifier: "com.apple.CoreSimulator.SimRuntime.iOS-\(version.replacingOccurrences(of: ".", with: "-"))",
                      version: version, supportedDeviceTypes: supported)
    }

    @Test func versionWindowRefusesRuntimeBelowMinimumNamingBothValues() {
        let error = SimulatorCreateValidation.versionWindowError(deviceType: versionedPhone(min: "26.0"), runtimeVersion: "25.1")
        #expect(error != nil)
        #expect(error?.contains("26.0") == true)
        #expect(error?.contains("25.1") == true)
    }

    @Test func versionWindowRefusesRuntimeAboveMaximumNamingBothValues() {
        let error = SimulatorCreateValidation.versionWindowError(deviceType: versionedPhone(max: "26.2"), runtimeVersion: "27.0")
        #expect(error != nil)
        #expect(error?.contains("26.2") == true)
        #expect(error?.contains("27.0") == true)
    }

    @Test func versionWindowAcceptsRuntimeInsideWindow() {
        #expect(SimulatorCreateValidation.versionWindowError(deviceType: versionedPhone(min: "26.0", max: "27.1"), runtimeVersion: "27.0") == nil)
        #expect(SimulatorCreateValidation.versionWindowError(deviceType: versionedPhone(min: "26.0"), runtimeVersion: "26.0") == nil)
        #expect(SimulatorCreateValidation.versionWindowError(deviceType: versionedPhone(), runtimeVersion: "27.0") == nil)
        #expect(SimulatorCreateValidation.versionWindowError(deviceType: versionedPhone(min: "26.0"), runtimeVersion: nil) == nil)
    }

    @Test func versionComparisonOrdersDottedVersionsNumerically() {
        #expect(SimulatorCreateValidation.compareVersions("26.10", "26.9") == .orderedDescending)
        #expect(SimulatorCreateValidation.compareVersions("26.0", "26.0.1") == .orderedAscending)
        #expect(SimulatorCreateValidation.compareVersions("27.0", "27.0") == .orderedSame)
    }

    @Test func validationErrorRefusesVersionWindowMismatch() {
        let error = SimulatorCreateValidation.validationError(
            name: "Phone",
            deviceType: versionedPhone(min: "26.0"),
            runtimeName: "iOS 25.1",
            runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.iOS-25-1",
            existingNames: [],
            runtimeRecord: iosRuntime(version: "25.1"))
        #expect(error?.contains("26.0") == true)
        #expect(error?.contains("25.1") == true)
    }

    @Test func validationErrorRefusesRuntimeWithoutDeviceTypeSupport() {
        let error = SimulatorCreateValidation.validationError(
            name: "Phone",
            deviceType: versionedPhone(),
            runtimeName: "iOS 27.0",
            runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.iOS-27-0",
            existingNames: [],
            runtimeRecord: iosRuntime(version: "27.0", supported: ["com.apple.CoreSimulator.SimDeviceType.iPhone-16"]))
        #expect(error?.contains("does not list") == true)
    }

    @Test func validationErrorAcceptsSupportedDeviceTypeInWindow() {
        let error = SimulatorCreateValidation.validationError(
            name: "Phone",
            deviceType: versionedPhone(min: "26.0", max: "27.1"),
            runtimeName: "iOS 27.0",
            runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.iOS-27-0",
            existingNames: [],
            runtimeRecord: iosRuntime(version: "27.0", supported: ["com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro"]))
        #expect(error == nil)
    }

    @Test func runtimeRecordCompatibilityChecksSupportAndWindow() {
        let phone = versionedPhone(min: "26.0")
        #expect(SimulatorCreateValidation.isCompatible(deviceType: phone, runtime: iosRuntime(version: "27.0", supported: ["com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro"])) == true)
        #expect(SimulatorCreateValidation.isCompatible(deviceType: phone, runtime: iosRuntime(version: "25.0", supported: ["com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro"])) == false)
        #expect(SimulatorCreateValidation.isCompatible(deviceType: phone, runtime: iosRuntime(version: "27.0", supported: ["com.apple.CoreSimulator.SimDeviceType.iPhone-16"])) == false)
    }
}
#endif
