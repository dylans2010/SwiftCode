import Foundation

public protocol PreAssembleValidator: Sendable {
    var id: String { get }
    var displayName: String { get }
    func validate(project: ReconstructedProject, configuration: BuildConfiguration) async throws -> [AssemblyDiagnostic]
}

public enum PreAssembleValidatorRegistry {
    private final class Store: @unchecked Sendable {
        var validators: [String: any PreAssembleValidator] = [:]
        let lock = NSLock()
    }

    private static let store = Store()

    public static func register(_ validator: any PreAssembleValidator) {
        store.lock.lock()
        defer { store.lock.unlock() }
        store.validators[validator.id] = validator
    }

    public static var validators: [any PreAssembleValidator] {
        store.lock.lock()
        defer { store.lock.unlock() }
        return store.validators.values.sorted { $0.id < $1.id }
    }
}
