import Foundation

public enum NativeBackends {
    public static func registerAll() {
        BackendRegistry.register(ClangBackend())
        BackendRegistry.register(SwiftBackend())
        BackendRegistry.register(RustBackend())
        BackendRegistry.register(GoBackend())
        BackendRegistry.register(ZigBackend())
    }
}
