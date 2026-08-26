import Foundation

public struct PairedMacDevice: Codable, Identifiable, Equatable {
    public let id: String
    public var name: String
    public var hostName: String
    public var port: UInt16
    public var datePaired: Date
    public var lastSeenDate: Date?
    public var isAutoConnectEnabled: Bool

    public init(
        id: String,
        name: String,
        hostName: String,
        port: UInt16,
        datePaired: Date = Date(),
        lastSeenDate: Date? = nil,
        isAutoConnectEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.hostName = hostName
        self.port = port
        self.datePaired = datePaired
        self.lastSeenDate = lastSeenDate
        self.isAutoConnectEnabled = isAutoConnectEnabled
    }
}

public final class ConnectTrustStore: ObservableObject {
    public static let shared = ConnectTrustStore()

    private let keychainService = KeychainService.shared
    private let pairedMacsKey = "com.swiftcode.connect.paired_macs"
    private let tokenPrefix = "com.swiftcode.connect.token."

    @Published public private(set) var pairedMacs: [PairedMacDevice] = []

    private init() {
        loadPairedMacs()
    }

    // MARK: - Mac Pairing Management

    public func loadPairedMacs() {
        guard let jsonString = keychainService.get(forKey: pairedMacsKey),
              let data = jsonString.data(using: .utf8) else {
            self.pairedMacs = []
            return
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let macs = try? decoder.decode([PairedMacDevice].self, from: data) {
            self.pairedMacs = macs
        } else {
            self.pairedMacs = []
        }
    }

    private func savePairedMacs() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(pairedMacs),
              let jsonString = String(data: data, encoding: .utf8) else {
            return
        }
        keychainService.set(jsonString, forKey: pairedMacsKey)
    }

    public func savePairedMac(_ mac: PairedMacDevice, authToken: String) {
        if let index = pairedMacs.firstIndex(where: { $0.id == mac.id }) {
            pairedMacs[index] = mac
        } else {
            pairedMacs.append(mac)
        }
        savePairedMacs()
        keychainService.set(authToken, forKey: tokenPrefix + mac.id)
    }

    public func updateLastSeen(for macID: String) {
        guard let index = pairedMacs.firstIndex(where: { $0.id == macID }) else { return }
        pairedMacs[index].lastSeenDate = Date()
        savePairedMacs()
    }

    public func setAutoConnect(for macID: String, enabled: Bool) {
        guard let index = pairedMacs.firstIndex(where: { $0.id == macID }) else { return }
        pairedMacs[index].isAutoConnectEnabled = enabled
        savePairedMacs()
    }

    public func removePairedMac(macID: String) {
        pairedMacs.removeAll { $0.id == macID }
        savePairedMacs()
        keychainService.delete(forKey: tokenPrefix + macID)
    }

    public func isPaired(macID: String) -> Bool {
        pairedMacs.contains { $0.id == macID }
    }

    public func getAuthToken(for macID: String) -> String? {
        keychainService.get(forKey: tokenPrefix + macID)
    }
}
