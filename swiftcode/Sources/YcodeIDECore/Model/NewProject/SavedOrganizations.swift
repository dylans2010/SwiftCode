import Foundation




public struct SavedOrganizations: @unchecked Sendable {
    public static let defaultsKey = "SwiftCode.newProjectOrganizations"
    public static let limit = 20

    public let defaults: UserDefaults

    public init(defaults: UserDefaults) { self.defaults = defaults }

    
    public var all: [String] {
        (defaults.stringArray(forKey: Self.defaultsKey) ?? []).filter { !$0.isEmpty }
    }

    public func contains(_ organization: String) -> Bool { all.contains(organization) }

    
    
    @discardableResult
    public func add(_ organization: String) -> Bool {
        let o = organization.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !o.isEmpty else { return false }
        var list = all.filter { $0 != o }
        list.insert(o, at: 0)
        defaults.set(Array(list.prefix(Self.limit)), forKey: Self.defaultsKey)
        return true
    }

    public func remove(_ organization: String) {
        defaults.set(all.filter { $0 != organization }, forKey: Self.defaultsKey)
    }
}
