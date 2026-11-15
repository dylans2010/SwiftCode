import Foundation
import YcodeDeviceModel

public struct DeviceRow: Equatable, Sendable {
    public var name: String
    public var identifier: String
    public var platform: String
    public var osVersion: String
    public var state: String
    public var model: String
    public var isAvailable: Bool
    public var isSwiftCodeRemote = false
    public var isFoldable = false
    public var deviceTypeID: String?
    public var deviceDirectory: String?
    public var isCreated = false
    public var architecture: String?
    public var buildVersion: String?

    public static func swiftcodeRemote(_ remote: RemoteSimulator, running: Bool) -> DeviceRow {
        let s = remote.settings
        return DeviceRow(name: remote.target?.name ?? RemoteSimulator.deviceName, identifier: "\(s.destination):\(remote.remoteDevicePath)",
                         platform: DevicePlatform(parsing: remote.target?.deviceType.platform).rawValue, osVersion: remote.runtimeVersion ?? "",
                         state: running ? "Booted" : "Shutdown",
                         model: remote.target.map { "\($0.deviceType.name), SwiftCode Simulator (Linux)" } ?? "SwiftCode Simulator (Linux)",
                         isAvailable: true, isSwiftCodeRemote: true, isFoldable: remote.isFoldable,
                         deviceTypeID: remote.target?.deviceType.id, deviceDirectory: remote.deviceDirectoryName,
                         isCreated: remote.target?.isCreated ?? false)
    }

    public static func shutDownSwiftCodeSimulator(name: String, identifier: String, osVersion: String? = nil) -> DeviceRow {
        DeviceRow(name: name, identifier: identifier, platform: "iOS", osVersion: osVersion ?? "", state: "Shutdown",
                  model: "SwiftCode Simulator", isAvailable: true, isSwiftCodeRemote: true, isFoldable: false)
    }
}
public enum DevicesList {
    public static func simulators(simctlJSON data: Data) -> [DeviceRow] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let byRuntime = root["devices"] as? [String: [[String: Any]]] else { return [] }
        var typeNames: [String: String] = [:]
        for t in root["devicetypes"] as? [[String: Any]] ?? [] {
            if let id = t["identifier"] as? String, let n = t["name"] as? String { typeNames[id] = n }
        }
        var versions: [String: String] = [:]
        var architectures: [String: String] = [:]
        var builds: [String: String] = [:]
        for r in root["runtimes"] as? [[String: Any]] ?? [] {
            guard let id = r["identifier"] as? String else { continue }
            if let v = r["version"] as? String { versions[id] = v }
            if let archs = r["supportedArchitectures"] as? [String], let first = archs.first { architectures[id] = first }
            if let b = r["buildversion"] as? String { builds[id] = b }
        }
        var out: [DeviceRow] = []
        for (runtime, devices) in byRuntime {
            let platform = DevicePlatform(runtimeIdentifier: runtime)
            guard platform != .unknown else { continue }
            let tail = runtime.split(separator: ".").last.map(String.init) ?? runtime
            let parts = tail.split(separator: "-").map(String.init)
            let version = versions[runtime] ?? parts.dropFirst().joined(separator: ".")
            for d in devices {
                guard let name = d["name"] as? String, let udid = d["udid"] as? String else { continue }
                let type = d["deviceTypeIdentifier"] as? String ?? ""
                out.append(DeviceRow(name: name, identifier: udid, platform: platform.rawValue, osVersion: version,
                                     state: d["state"] as? String ?? "", model: typeNames[type] ?? type.split(separator: ".").last.map(String.init) ?? "",
                                     isAvailable: d["isAvailable"] as? Bool ?? true,
                                     architecture: architectures[runtime], buildVersion: builds[runtime]))
            }
        }
        return out.sorted {
            if $0.platform != $1.platform { return $0.platform < $1.platform }
            if $0.name != $1.name { return $0.name < $1.name }
            return $0.osVersion.compare($1.osVersion, options: .numeric) == .orderedAscending
        }
    }

    public static func simulatorRows(from result: SimctlDiscoveryResult) -> [DeviceRow] {
        var typeNames: [String: String] = [:]
        for t in result.deviceTypes { typeNames[t.identifier] = t.name }
        var runtimesByID: [String: RuntimeDTO] = [:]
        for r in result.runtimes { runtimesByID[r.identifier] = r }
        var out: [DeviceRow] = []
        for (runtimeID, devices) in result.devices {
            let platform = DevicePlatform(runtimeIdentifier: runtimeID)
            guard platform != .unknown else { continue }
            let runtime = runtimesByID[runtimeID]
            let cleanRuntimeID = runtimeID.replacingOccurrences(of: "com.apple.CoreSimulator.SimRuntime.", with: "")
            let parts = cleanRuntimeID.split(separator: "-")
            let version = runtime?.version ?? parts.dropFirst().joined(separator: ".")
            for d in devices {
                let type = d.deviceTypeIdentifier ?? ""
                out.append(DeviceRow(name: d.name, identifier: d.udid, platform: platform.rawValue, osVersion: version,
                                     state: d.state, model: typeNames[type] ?? type.split(separator: ".").last.map(String.init) ?? "",
                                     isAvailable: d.isAvailable,
                                     architecture: runtime?.supportedArchitectures?.first, buildVersion: runtime?.buildversion))
            }
        }
        return out.sorted {
            if $0.platform != $1.platform { return $0.platform < $1.platform }
            if $0.name != $1.name { return $0.name < $1.name }
            return $0.osVersion.compare($1.osVersion, options: .numeric) == .orderedAscending
        }
    }

    public static func parsePhysicalDevices(data: Data) throws -> [DeviceRow] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = root["result"] as? [String: Any],
              let list = result["devices"] as? [[String: Any]] else {
            throw DeviceDiscoveryError.invalidJSON("devicectl list devices output has no result.devices array.")
        }
        return list.compactMap { d in
            let hw = d["hardwareProperties"] as? [String: Any] ?? [:]
            let props = d["deviceProperties"] as? [String: Any] ?? [:]
            let conn = d["connectionProperties"] as? [String: Any] ?? [:]
            guard (hw["reality"] as? String ?? "physical") == "physical", let name = props["name"] as? String else { return nil }
            let pairing = conn["pairingState"] as? String ?? ""
            let tunnel = conn["tunnelState"] as? String ?? ""
            return DeviceRow(name: name, identifier: d["identifier"] as? String ?? hw["udid"] as? String ?? "",
                             platform: DevicePlatform(parsing: hw["platform"] as? String).rawValue,
                             osVersion: props["osVersionNumber"] as? String ?? "",
                             state: [pairing, tunnel].filter { !$0.isEmpty }.joined(separator: ", "),
                             model: hw["marketingName"] as? String ?? hw["productType"] as? String ?? "", isAvailable: true,
                             architecture: hw["cpuType"] as? String ?? hw["architecture"] as? String,
                             buildVersion: props["buildVersion"] as? String ?? props["osBuildVersion"] as? String)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    public static func devices(devicectlJSON data: Data) throws -> [DeviceRow] {
        try parsePhysicalDevices(data: data)
    }

    public static func load() async throws -> (devices: [DeviceRow], simulators: [DeviceRow]) {
        let snapshot = try await DeviceDiscoveryService.shared.discover()
        return (snapshot.devices, snapshot.simulators)
    }
}
