import Foundation

public enum EmbeddedBackends {
    public static func registerAll() {
        BackendRegistry.register(JavaScriptBackend())
        BackendRegistry.register(JavaJVMBackend())
        BackendRegistry.register(PythonBackend())
        BackendRegistry.register(LuaBackend())
    }
}
