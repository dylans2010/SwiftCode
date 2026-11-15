import Foundation

public struct DeviceHubRuntimeEntry: Sendable, Equatable, Hashable, Identifiable {
    public var id: String { identifier }
    public var identifier: String
    public var name: String
    public var version: String
    public var buildVersion: String?
    public var platform: DevicePlatform
    public var isAvailable: Bool
    public var path: String?
    public var sizeBytes: Int64?
    public var supportedDeviceTypes: [String]

    public init(
        identifier: String,
        name: String,
        version: String,
        buildVersion: String? = nil,
        platform: DevicePlatform,
        isAvailable: Bool = true,
        path: String? = nil,
        sizeBytes: Int64? = nil,
        supportedDeviceTypes: [String] = []
    ) {
        self.identifier = identifier
        self.name = name
        self.version = version
        self.buildVersion = buildVersion
        self.platform = platform
        self.isAvailable = isAvailable
        self.path = path
        self.sizeBytes = sizeBytes
        self.supportedDeviceTypes = supportedDeviceTypes
    }

    public var sizeDisplay: String {
        guard let sizeBytes else { return "unknown" }
        return ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }

    public var displayName: String {
        version.isEmpty ? name : "\(name) (\(version))"
    }

    public static func parseRuntimesJSON(_ data: Data) -> [DeviceHubRuntimeEntry] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = json["runtimes"] as? [[String: Any]] else { return [] }
        return list.compactMap { dict in
            guard let identifier = dict["identifier"] as? String,
                  let name = dict["name"] as? String,
                  let version = dict["version"] as? String else { return nil }
            let platform = DevicePlatform(runtimeIdentifier: identifier)
            guard platform != .unknown else { return nil }
            return DeviceHubRuntimeEntry(
                identifier: identifier,
                name: name,
                version: version,
                buildVersion: dict["buildversion"] as? String,
                platform: platform,
                isAvailable: (dict["isAvailable"] as? Bool) ?? true,
                supportedDeviceTypes: dict["supportedDeviceTypes"] as? [String] ?? []
            )
        }
    }

    public static func directorySize(atPath path: String, fileManager: FileManager = .default) -> Int64? {
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { return nil }
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: []
        ) else { return nil }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true else { continue }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }

    public func withDiskSize(fileManager: FileManager = .default) -> DeviceHubRuntimeEntry {
        guard let path else { return self }
        var copy = self
        copy.sizeBytes = Self.directorySize(atPath: path, fileManager: fileManager)
        return copy
    }

    public func withDiskPath(_ path: String?) -> DeviceHubRuntimeEntry {
        var copy = self
        copy.path = path
        return copy
    }

    public static func merged(simctlEntries: [DeviceHubRuntimeEntry], diskPaths: [String: String]) -> [DeviceHubRuntimeEntry] {
        simctlEntries.map { entry in
            guard let path = diskPaths[entry.identifier] ?? diskPaths[entry.name] else { return entry }
            return entry.withDiskPath(path)
        }
    }
}

public enum DeviceHubRuntimeBrowserError: Error, LocalizedError, Sendable {
    case listFailed(String)
    case removeFailed(String)
    case runtimeNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .listFailed(let detail):
            return detail.isEmpty ? "Listing simulator runtimes failed." : "Listing simulator runtimes failed: \(detail)"
        case .removeFailed(let detail):
            return detail.isEmpty ? "Removing the simulator runtime failed." : "Removing the simulator runtime failed: \(detail)"
        case .runtimeNotFound(let identifier):
            return "Runtime \(identifier) was not found in a fresh simctl runtime list."
        }
    }
}

public struct DeviceHubRuntimeBrowser: Sendable {
    public init() {}

    public func listRuntimes() async throws -> [DeviceHubRuntimeEntry] {
        let result = try await DeviceConnectProcessRunner.shared.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/xcrun"),
            arguments: ["simctl", "list", "-j", "runtimes"],
            timeout: 30
        )
        guard result.exitCode == 0, let data = result.stdout.data(using: .utf8) else {
            let detail = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw DeviceHubRuntimeBrowserError.listFailed(detail)
        }
        return DeviceHubRuntimeEntry.parseRuntimesJSON(data)
    }

    public func verifyInstalled(identifier: String) async throws -> Bool {
        let runtimes = try await listRuntimes()
        return runtimes.contains { $0.identifier == identifier }
    }

    public func verifyInstalled(platform: DevicePlatform, version: String? = nil) async throws -> Bool {
        let runtimes = try await listRuntimes()
        return runtimes.contains { entry in
            guard entry.platform == platform, entry.isAvailable else { return false }
            if let version, !version.isEmpty { return entry.version == version }
            return true
        }
    }

    public func removeRuntime(identifier: String) async throws {
        let result = try await DeviceConnectProcessRunner.shared.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/xcrun"),
            arguments: ["simctl", "runtime", "delete", identifier],
            timeout: 120
        )
        guard result.exitCode == 0 else {
            let detail = (result.stdout + result.stderr).trimmingCharacters(in: .whitespacesAndNewlines)
            throw DeviceHubRuntimeBrowserError.removeFailed(detail)
        }
    }
}
