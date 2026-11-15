import Foundation
import YcodeDeviceModel

public enum DeveloperTools {
    public struct Tool: Equatable, Sendable {
        public var name: String
        public var url: URL
    }

    public static let order = ["Instruments", "Device Hub", "Icon Composer", "Accessibility Inspector", "FileMerge", "Create ML"]

    public static func tools(inDeveloperDirectory dir: URL, exists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }) -> [Tool] {
        order.compactMap { name in
            let url = dir.appendingPathComponent("Applications").appendingPathComponent(name + ".app")
            return exists(url.path) ? Tool(name: name, url: url) : nil
        }
    }

    public static func activeDeveloperDirectory() async -> URL? {
        if let d = ProcessInfo.processInfo.environment["DEVELOPER_DIR"], !d.isEmpty { return URL(fileURLWithPath: d) }
        guard let result = try? await DeviceConnectProcessRunner.shared.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/xcode-select"),
            arguments: ["-p"],
            timeout: 10
        ) else { return nil }
        let s = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.exitCode == 0 && !s.isEmpty ? URL(fileURLWithPath: s) : nil
    }

    @MainActor public static var installed: [Tool] {
        if let cached { return cached }
        prefetch()
        return []
    }

    @MainActor private static var cached: [Tool]?

    nonisolated static func lookUp() async -> [Tool] { await activeDeveloperDirectory().map { tools(inDeveloperDirectory: $0) } ?? [] }

    @MainActor public static func prefetch() {
        guard cached == nil, !fetching else { return }
        fetching = true
        Task {
            let list = await lookUp()
            cached = list
            fetching = false
        }
    }

    @MainActor private static var fetching = false
}
