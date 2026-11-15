import Foundation

public struct DeviceGroup: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var deviceIDs: [String]
    public var createdAt: Date

    public init(id: UUID = UUID(), name: String, deviceIDs: [String] = [], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.deviceIDs = deviceIDs
        self.createdAt = createdAt
    }

    public func contains(_ deviceID: String) -> Bool {
        deviceIDs.contains(deviceID)
    }

    public func adding(_ deviceID: String) -> DeviceGroup {
        guard !deviceIDs.contains(deviceID) else { return self }
        var copy = self
        copy.deviceIDs.append(deviceID)
        return copy
    }

    public func removing(_ deviceID: String) -> DeviceGroup {
        var copy = self
        copy.deviceIDs.removeAll { $0 == deviceID }
        return copy
    }

    public func renamed(to newName: String) -> DeviceGroup {
        var copy = self
        copy.name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        return copy
    }
}

public struct DeviceGroupOperationFailure: Sendable, Equatable {
    public var deviceID: String
    public var error: String

    public init(deviceID: String, error: String) {
        self.deviceID = deviceID
        self.error = error
    }
}

public struct DeviceGroupOperationResult: Sendable, Equatable {
    public var succeededIDs: [String]
    public var failures: [DeviceGroupOperationFailure]

    public init(succeededIDs: [String] = [], failures: [DeviceGroupOperationFailure] = []) {
        self.succeededIDs = succeededIDs
        self.failures = failures
    }

    public var allSucceeded: Bool { failures.isEmpty }

    public var summary: String {
        if failures.isEmpty {
            return succeededIDs.count == 1 ? "1 device updated" : "\(succeededIDs.count) devices updated"
        }
        let failedNames = failures.map(\.deviceID).joined(separator: ", ")
        return "\(succeededIDs.count) updated, \(failures.count) failed (\(failedNames))"
    }
}

public enum DeviceHubStoreKeys {
    public static let groups = "SwiftCode.deviceHub.deviceGroups"
    public static let preferredDevices = "SwiftCode.deviceHub.preferredDevices"
    public static let simulatorSelection = "SwiftCode.deviceHub.simulatorSelection"
    public static let section = "SwiftCode.deviceHub.section"
    public static let batteryLevelPrefix = "SwiftCode.deviceHub.batteryLevel."
    public static let appearancePrefix = "SwiftCode.deviceHub.appearance."

    public static func batteryLevelKey(udid: String) -> String { batteryLevelPrefix + udid }
    public static func appearanceKey(udid: String) -> String { appearancePrefix + udid }
}

public struct DeviceGroupStore: @unchecked Sendable {
    public var defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public static func decodeGroups(from data: Data?) -> [DeviceGroup] {
        guard let data, !data.isEmpty else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let groups = try? decoder.decode([DeviceGroup].self, from: data) else { return [] }
        return groups.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    public static func encodeGroups(_ groups: [DeviceGroup]) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try? encoder.encode(groups)
    }

    public func loadGroups() -> [DeviceGroup] {
        Self.decodeGroups(from: defaults.data(forKey: DeviceHubStoreKeys.groups))
    }

    public func saveGroups(_ groups: [DeviceGroup]) {
        if let data = Self.encodeGroups(groups) {
            defaults.set(data, forKey: DeviceHubStoreKeys.groups)
        } else {
            defaults.removeObject(forKey: DeviceHubStoreKeys.groups)
        }
    }

    @discardableResult
    public func createGroup(name: String) -> DeviceGroup? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var groups = loadGroups()
        guard !groups.contains(where: { $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) else { return nil }
        let group = DeviceGroup(name: trimmed)
        groups.append(group)
        saveGroups(groups)
        return group
    }

    @discardableResult
    public func deleteGroup(id: UUID) -> Bool {
        var groups = loadGroups()
        let before = groups.count
        groups.removeAll { $0.id == id }
        guard groups.count != before else { return false }
        saveGroups(groups)
        return true
    }

    @discardableResult
    public func renameGroup(id: UUID, name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        var groups = loadGroups()
        guard let index = groups.firstIndex(where: { $0.id == id }) else { return false }
        guard !groups.contains(where: { $0.id != id && $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) else { return false }
        groups[index] = groups[index].renamed(to: trimmed)
        saveGroups(groups)
        return true
    }

    @discardableResult
    public func addDevice(_ deviceID: String, toGroup id: UUID) -> Bool {
        var groups = loadGroups()
        guard let index = groups.firstIndex(where: { $0.id == id }) else { return false }
        let updated = groups[index].adding(deviceID)
        guard updated != groups[index] else { return false }
        groups[index] = updated
        saveGroups(groups)
        return true
    }

    @discardableResult
    public func removeDevice(_ deviceID: String, fromGroup id: UUID) -> Bool {
        var groups = loadGroups()
        guard let index = groups.firstIndex(where: { $0.id == id }) else { return false }
        let updated = groups[index].removing(deviceID)
        guard updated != groups[index] else { return false }
        groups[index] = updated
        saveGroups(groups)
        return true
    }

    public func groupsContaining(deviceID: String) -> [DeviceGroup] {
        loadGroups().filter { $0.contains(deviceID) }
    }

    public func pruneMissingDevices(knownIDs: Set<String>) -> [DeviceGroup] {
        let groups = loadGroups().map { group in
            DeviceGroup(id: group.id, name: group.name, deviceIDs: group.deviceIDs.filter { knownIDs.contains($0) }, createdAt: group.createdAt)
        }
        saveGroups(groups)
        return groups
    }

    public func preferredDeviceIDs() -> [String] {
        defaults.stringArray(forKey: DeviceHubStoreKeys.preferredDevices) ?? []
    }

    public func setPreferredDeviceIDs(_ ids: [String]) {
        defaults.set(ids, forKey: DeviceHubStoreKeys.preferredDevices)
    }

    public func markPreferred(_ deviceID: String) {
        var ids = preferredDeviceIDs()
        guard !ids.contains(deviceID) else { return }
        ids.append(deviceID)
        setPreferredDeviceIDs(ids)
    }

    public func unmarkPreferred(_ deviceID: String) {
        setPreferredDeviceIDs(preferredDeviceIDs().filter { $0 != deviceID })
    }

    public func isPreferred(_ deviceID: String) -> Bool {
        preferredDeviceIDs().contains(deviceID)
    }

    public func savedSimulatorSelection() -> String? {
        defaults.string(forKey: DeviceHubStoreKeys.simulatorSelection)
    }

    public func saveSimulatorSelection(_ id: String?) {
        if let id, !id.isEmpty {
            defaults.set(id, forKey: DeviceHubStoreKeys.simulatorSelection)
        } else {
            defaults.removeObject(forKey: DeviceHubStoreKeys.simulatorSelection)
        }
    }

    public func savedBatteryLevel(udid: String) -> Int? {
        let value = defaults.integer(forKey: DeviceHubStoreKeys.batteryLevelKey(udid: udid))
        return defaults.object(forKey: DeviceHubStoreKeys.batteryLevelKey(udid: udid)) == nil ? nil : value
    }

    public func saveBatteryLevel(_ level: Int, udid: String) {
        defaults.set(min(100, max(0, level)), forKey: DeviceHubStoreKeys.batteryLevelKey(udid: udid))
    }

    public func savedAppearanceIsDark(udid: String) -> Bool? {
        guard let value = defaults.object(forKey: DeviceHubStoreKeys.appearanceKey(udid: udid)) as? Bool else { return nil }
        return value
    }

    public func saveAppearanceIsDark(_ isDark: Bool, udid: String) {
        defaults.set(isDark, forKey: DeviceHubStoreKeys.appearanceKey(udid: udid))
    }
}
