import Foundation

public enum BackendRegistry {
    private final class Store: @unchecked Sendable {
        var byID: [String: any AssembleBackend] = [:]
        let lock = NSLock()
    }

    private static let store = Store()

    private static let defaultsRegistered: Bool = {
        NativeBackends.registerAll()
        NativeBackendsB.registerAll()
        return true
    }()

    private static func ensureDefaults() {
        _ = defaultsRegistered
    }

    public static func register(_ backend: any AssembleBackend) {
        store.lock.lock()
        defer { store.lock.unlock() }
        store.byID[backend.id] = backend
    }

    public static func backend(id: String) -> (any AssembleBackend)? {
        ensureDefaults()
        store.lock.lock()
        defer { store.lock.unlock() }
        return store.byID[id]
    }

    public static func backend(forExtension ext: String) -> (any AssembleBackend)? {
        ensureDefaults()
        let normalized = ext.lowercased()
        store.lock.lock()
        defer { store.lock.unlock() }
        return store.byID.values.first { $0.sourceExtensions.contains(normalized) }
    }

    public static func allBackends() -> [any AssembleBackend] {
        ensureDefaults()
        store.lock.lock()
        defer { store.lock.unlock() }
        return store.byID.values.sorted { $0.id < $1.id }
    }

    public static func allSourceExtensions() -> Set<String> {
        Set(allBackends().flatMap(\.sourceExtensions))
    }

    public static func allDiscoveryRoots() -> [String] {
        var roots: [String] = []
        for backend in allBackends() {
            for root in backend.discoveryRoots where !roots.contains(root) {
                roots.append(root)
            }
        }
        return roots.sorted()
    }

    public static func availableBackends(configuration: BuildConfiguration) -> [(any AssembleBackend, BackendAvailability)] {
        allBackends().map { ($0, $0.availability(configuration: configuration)) }
    }
}
