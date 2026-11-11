import Foundation

public enum BackendToolDiscovery {
    public static func locateViaXcrun(tool: String) -> String? {
        for xcrun in ["/usr/bin/xcrun", "/bin/xcrun"] {
            guard FileManager.default.isExecutableFile(atPath: xcrun) else { continue }
            guard let output = try? ProcessRunnerRegistry.shared.run(
                executable: xcrun, arguments: ["-f", tool], environment: nil, currentDirectory: nil),
                  output.status == 0 else { continue }
            let path = output.stdoutText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

    public static func locateInFixedPaths(_ candidates: [String]) -> String? {
        for candidate in candidates {
            let expanded = (candidate as NSString).expandingTildeInPath
            if FileManager.default.isExecutableFile(atPath: expanded) { return expanded }
        }
        return nil
    }

    public static func locateOnPATH(_ names: [String]) -> String? {
        let pathDirs = (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map(String.init)
        for dir in pathDirs {
            for name in names {
                let candidate = (dir as NSString).appendingPathComponent(name)
                if FileManager.default.isExecutableFile(atPath: candidate) { return candidate }
            }
        }
        return nil
    }

    public static func locate(xcrunTool: String? = nil, fixedPaths: [String], pathNames: [String]) -> String? {
        if let xcrunTool, let found = locateViaXcrun(tool: xcrunTool) { return found }
        if let found = locateInFixedPaths(fixedPaths) { return found }
        return locateOnPATH(pathNames)
    }

    public static func toolVersion(_ path: String, arguments: [String] = ["--version"]) -> String? {
        guard let output = try? ProcessRunnerRegistry.shared.run(
            executable: path, arguments: arguments, environment: nil, currentDirectory: nil),
              output.status == 0 else { return nil }
        let text = (output.stdoutText + "\n" + output.stderrText)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        return text.components(separatedBy: "\n").first?.trimmingCharacters(in: .whitespaces)
    }
}
