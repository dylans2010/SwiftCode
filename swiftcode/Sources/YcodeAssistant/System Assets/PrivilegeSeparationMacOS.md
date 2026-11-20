<!-- system-index-depends: AppSandboxSecurity.md -->
# Privilege Separation & Secure Inter-Process Communication (XPC)

Architecture for separating untrusted user code execution from elevated system tasks using XPC Services and `SMAppService`.

---

## 1. Principle of Least Privilege
Do not execute unsandboxed actions or dangerous child processes inside the main GUI application process.
- **Main GUI Process:** Sandboxed, communicates with the user, handles rendering.
- **XPC Helper Daemon:** Lightweight, isolated helper process invoked via Mach messages for background tasks.

---

## 2. Defining XPC Protocols
```swift
@objc(BuildToolXPCProtocol)
public protocol BuildToolXPCProtocol {
    func executeBuild(projectPath: String, withReply reply: @escaping (Int32, String) -> Void)
}

final class XPCClientManager: Sendable {
    private let connection: NSXPCConnection

    init() {
        connection = NSXPCConnection(serviceName: "com.swiftcode.BuildHelper")
        connection.remoteObjectInterface = NSXPCInterface(with: BuildToolXPCProtocol.self)
        connection.resume()
    }

    func execute(path: String) async throws -> String {
        let proxy = connection.remoteObjectProxy as? BuildToolXPCProtocol
        // Await reply block
        return "OK"
    }
}
```
