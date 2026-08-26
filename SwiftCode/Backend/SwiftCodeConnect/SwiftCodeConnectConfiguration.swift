import Foundation

/// Single source of truth for SwiftCode Connect configuration on this device.
public struct SwiftCodeConnectConfiguration: Codable, Equatable, Sendable {
    public static let defaultPort: UInt16 = 8088
    public static let minPort: UInt16 = 1024
    public static let maxPort: UInt16 = 65535

    public var port: UInt16
    public var autoConnect: Bool
    public var advertiseService: Bool
    public var manualHost: String
    public var manualPort: UInt16

    public init(
        port: UInt16 = SwiftCodeConnectConfiguration.defaultPort,
        autoConnect: Bool = true,
        advertiseService: Bool = true,
        manualHost: String = "",
        manualPort: UInt16 = SwiftCodeConnectConfiguration.defaultPort
    ) {
        self.port = port
        self.autoConnect = autoConnect
        self.advertiseService = advertiseService
        self.manualHost = manualHost
        self.manualPort = manualPort
    }

    /// Validates whether a port number is acceptable for TCP listening/connecting.
    public static func isValidPort(_ port: UInt16) -> Bool {
        return port >= minPort && port <= maxPort
    }

    /// Validates whether the given string is a valid port number.
    public static func validatePortString(_ string: String) -> UInt16? {
        guard let port = UInt16(string.trimmingCharacters(in: .whitespacesAndNewlines)),
              isValidPort(port) else {
            return nil
        }
        return port
    }
}

/// Persistent configuration manager for SwiftCode Connect settings.
@MainActor
public final class ConnectConfigurationManager: ObservableObject {
    public static let shared = ConnectConfigurationManager()

    private let userDefaultsKey = "com.swiftcode.connect.configuration"

    @Published public private(set) var configuration: SwiftCodeConnectConfiguration {
        didSet {
            saveConfiguration()
        }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let saved = try? JSONDecoder().decode(SwiftCodeConnectConfiguration.self, from: data) {
            self.configuration = saved
        } else {
            self.configuration = SwiftCodeConnectConfiguration()
        }
    }

    public func updatePort(_ newPort: UInt16) {
        guard SwiftCodeConnectConfiguration.isValidPort(newPort) else { return }
        var updated = configuration
        updated.port = newPort
        self.configuration = updated
    }

    public func setAutoConnect(_ enabled: Bool) {
        var updated = configuration
        updated.autoConnect = enabled
        self.configuration = updated
    }

    public func setAdvertiseService(_ enabled: Bool) {
        var updated = configuration
        updated.advertiseService = enabled
        self.configuration = updated
    }

    public func updateManualEndpoint(host: String, port: UInt16) {
        var updated = configuration
        updated.manualHost = host
        updated.manualPort = port
        self.configuration = updated
    }

    private func saveConfiguration() {
        if let data = try? JSONEncoder().encode(configuration) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
}
