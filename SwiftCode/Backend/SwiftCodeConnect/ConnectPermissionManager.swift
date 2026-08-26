import Foundation

public enum ConnectPermission: String, Codable, CaseIterable, Identifiable {
    case projectInfo = "project_info"
    case build = "build"
    case tests = "tests"
    case logs = "logs"
    case assist = "assist"
    case deviceInfo = "device_info"
    case terminal = "terminal"
    case fileModification = "file_modification"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .projectInfo: return "Project Information"
        case .build: return "Build Control"
        case .tests: return "Test Execution"
        case .logs: return "Streaming Logs"
        case .assist: return "Assist Context"
        case .deviceInfo: return "Device Metrics"
        case .terminal: return "Terminal Execution"
        case .fileModification: return "File Modifications"
        }
    }

    public var iconName: String {
        switch self {
        case .projectInfo: return "folder.fill"
        case .build: return "hammer.fill"
        case .tests: return "checkmark.seal.fill"
        case .logs: return "terminal.fill"
        case .assist: return "sparkles"
        case .deviceInfo: return "desktopcomputer"
        case .terminal: return "command"
        case .fileModification: return "square.and.pencil"
        }
    }

    public var isSensitive: Bool {
        switch self {
        case .terminal, .fileModification:
            return true
        default:
            return false
        }
    }
}

public final class ConnectPermissionManager: ObservableObject {
    public static let shared = ConnectPermissionManager()

    private let defaultsKeyPrefix = "com.swiftcode.connect.permissions."

    @Published private var permissionsMap: [String: Set<ConnectPermission>] = [:]

    private init() {}

    public func permissions(for macID: String) -> Set<ConnectPermission> {
        if let existing = permissionsMap[macID] {
            return existing
        }
        let key = defaultsKeyPrefix + macID
        if let rawArray = UserDefaults.standard.array(forKey: key) as? [String] {
            let set = Set(rawArray.compactMap { ConnectPermission(rawValue: $0) })
            permissionsMap[macID] = set
            return set
        }
        // Default permissions for new Mac (all non-sensitive)
        let defaultSet = Set(ConnectPermission.allCases.filter { !$0.isSensitive })
        savePermissions(defaultSet, for: macID)
        return defaultSet
    }

    public func hasPermission(_ permission: ConnectPermission, for macID: String) -> Bool {
        permissions(for: macID).contains(permission)
    }

    public func setPermission(_ permission: ConnectPermission, isGranted: Bool, for macID: String) {
        var current = permissions(for: macID)
        if isGranted {
            current.insert(permission)
        } else {
            current.remove(permission)
        }
        savePermissions(current, for: macID)
    }

    public func savePermissions(_ permissions: Set<ConnectPermission>, for macID: String) {
        permissionsMap[macID] = permissions
        let rawArray = permissions.map { $0.rawValue }
        UserDefaults.standard.set(rawArray, forKey: defaultsKeyPrefix + macID)
    }
}
