import Foundation

public struct BuildParser {
    public struct ParsedIssue: Sendable {
        public let filePath: String?
        public let line: Int?
        public let message: String
        public let isError: Bool
    }

    public static func parseXcodebuildOutput(_ text: String) -> (errors: [ParsedIssue], warnings: [ParsedIssue]) {
        var errors: [ParsedIssue] = []
        var warnings: [ParsedIssue] = []

        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            if line.contains(": error:") {
                if let issue = parseDiagnosticLine(line, isError: true) {
                    errors.append(issue)
                }
            } else if line.contains(": warning:") {
                if let issue = parseDiagnosticLine(line, isError: false) {
                    warnings.append(issue)
                }
            }
        }

        return (errors, warnings)
    }

    private static func parseDiagnosticLine(_ line: String, isError: Bool) -> ParsedIssue? {
        let parts = line.components(separatedBy: isError ? ": error:" : ": warning:")
        guard parts.count >= 2 else { return nil }

        let fileAndCoords = parts[0].trimmingCharacters(in: .whitespaces)
        let message = parts[1].trimmingCharacters(in: .whitespaces)

        let subParts = fileAndCoords.components(separatedBy: ":")
        if subParts.count >= 2 {
            let path = subParts[0]
            let lineNum = Int(subParts[1])
            return ParsedIssue(filePath: path, line: lineNum, message: message, isError: isError)
        }

        return ParsedIssue(filePath: nil, line: nil, message: message, isError: isError)
    }
}

public struct CommandParser {
    public static func parseJSON<T: Decodable>(_ dataString: String, as type: T.Type) -> T? {
        guard let data = dataString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    public static func splitLines(_ output: String) -> [String] {
        return output.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

public struct DeviceInfoDetails: Sendable {
    public let identifier: String
    public let name: String?
    public let platform: String
    public let osVersion: String?
    public let buildVersion: String?
    public let architecture: String?
    public let model: String?
    public let developerModeEnabled: Bool?
    public let trusted: Bool?
    public let connectionState: String

    public init(
        identifier: String,
        name: String?,
        platform: String,
        osVersion: String?,
        buildVersion: String?,
        architecture: String?,
        model: String?,
        developerModeEnabled: Bool?,
        trusted: Bool?,
        connectionState: String
    ) {
        self.identifier = identifier
        self.name = name
        self.platform = platform
        self.osVersion = osVersion
        self.buildVersion = buildVersion
        self.architecture = architecture
        self.model = model
        self.developerModeEnabled = developerModeEnabled
        self.trusted = trusted
        self.connectionState = connectionState
    }

    public enum ParsingError: Error, LocalizedError, Sendable {
        case invalidJSON
        case missingDevice

        public var errorDescription: String? {
            switch self {
            case .invalidJSON:
                return "devicectl device info output is not valid JSON."
            case .missingDevice:
                return "devicectl device info output contains no device."
            }
        }
    }

    public static func parse(data: Data, deviceUDID: String) throws -> DeviceInfoDetails {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = root["result"] as? [String: Any] else {
            throw ParsingError.invalidJSON
        }
        let candidate: [String: Any]
        if let devices = result["devices"] as? [[String: Any]], let first = devices.first {
            candidate = first
        } else if let device = result["device"] as? [String: Any] {
            candidate = device
        } else if result["deviceProperties"] != nil || result["hardwareProperties"] != nil {
            candidate = result
        } else {
            throw ParsingError.missingDevice
        }
        let hardware = candidate["hardwareProperties"] as? [String: Any] ?? [:]
        let properties = candidate["deviceProperties"] as? [String: Any] ?? [:]
        let connection = candidate["connectionProperties"] as? [String: Any] ?? [:]
        let pairing = connection["pairingState"] as? String
        let tunnel = connection["tunnelState"] as? String
        let trusted: Bool?
        if pairing == "paired" {
            trusted = true
        } else if pairing == "unpaired" {
            trusted = false
        } else {
            trusted = nil
        }
        return DeviceInfoDetails(
            identifier: candidate["identifier"] as? String ?? hardware["udid"] as? String ?? deviceUDID,
            name: properties["name"] as? String,
            platform: DevicePlatform(parsing: hardware["platform"] as? String).rawValue,
            osVersion: properties["osVersionNumber"] as? String,
            buildVersion: properties["buildVersion"] as? String ?? properties["osBuildVersion"] as? String,
            architecture: hardware["cpuType"] as? String ?? hardware["architecture"] as? String,
            model: hardware["marketingName"] as? String ?? hardware["productType"] as? String,
            developerModeEnabled: properties["developerMode"] as? Bool ?? properties["developerModeEnabled"] as? Bool,
            trusted: trusted,
            connectionState: [pairing, tunnel].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
        )
    }
}

public struct DeviceParser {
    public static func parseXCDeviceList(_ jsonString: String) -> [ConnectedDevice] {
        guard let data = jsonString.data(using: .utf8) else { return [] }

        struct XCDeviceItem: Decodable {
            let name: String?
            let model: String?
            let platform: String?
            let operatingSystemVersion: String?
            let buildVersion: String?
            let architecture: String?
            let identifier: String?
            let modelUTI: String?
            let isWirelesslyConnected: Bool?
            let isConnected: Bool?
            let isAvailable: Bool?
        }

        guard let items = try? JSONDecoder().decode([XCDeviceItem].self, from: data) else {
            return []
        }

        return items.compactMap { item in
            guard let id = item.identifier else { return nil }
            return ConnectedDevice(
                name: item.name ?? "Unknown",
                model: item.model ?? "Unknown",
                productType: item.modelUTI ?? "Unknown",
                platform: DevicePlatform(parsing: item.platform).rawValue,
                osVersion: item.operatingSystemVersion ?? "Unknown",
                buildVersion: item.buildVersion ?? "Unknown",
                architecture: item.architecture ?? "Unknown",
                udid: id,
                isConnected: item.isConnected ?? true,
                isAvailable: item.isAvailable ?? true,
                isWireless: item.isWirelesslyConnected ?? false
            )
        }
    }
}

public struct DiagnosticsFormatter {
    public static func formatEnvironmentDiagnostics(_ env: DeviceEnvironment) -> [String] {
        var diagnostics: [String] = []

        if env.xcodeVersion == nil {
            diagnostics.append("Missing: Xcode is not detected or registered in the environment. Please run 'xcode-select -s /Applications/Xcode.app' to set your path.")
        }
        if !env.hasiOSSDK {
            diagnostics.append("Missing SDK: The iOS SDK could not be verified. Ensure iOS build support is checked in your Xcode installations.")
        }
        if !env.isSigningSetup {
            diagnostics.append("Warning: Signing profiles are unverified. Builds might fail on physical devices unless codesigning is set up correctly in SwiftCode Accounts settings.")
        }

        if diagnostics.isEmpty {
            diagnostics.append("All checks passed. System is fully compatible with DeviceConnect deployment pipelines.")
        }

        return diagnostics
    }

    public static func formatPipelineFailure(stage: DeploymentStatus, error: String) -> String {
        return """
        Deployment failed at stage: \(stage.description)
        Timestamp: \(ISO8601DateFormatter().string(from: Date()))
        Error Details: \(error)
        Suggested Action: Device readiness was not probed for this failure. Run Check Trust & Developer Mode on the device, or call the device-specific failure format, to report the detected state instead of this generic hint.
        """
    }

    public static func formatPipelineFailure(stage: DeploymentStatus, error: String, readiness: PhysicalDeviceReadiness) -> String {
        let guidance = readiness.actionGuidance ?? "The device is trusted and Developer Mode is on, so trust and Developer Mode do not explain this failure."
        return """
        Deployment failed at stage: \(stage.description)
        Timestamp: \(ISO8601DateFormatter().string(from: Date()))
        Error Details: \(error)
        Detected Device State: \(readiness.summary)
        Suggested Action: \(guidance)
        """
    }

    public static func formatPipelineFailure(stage: DeploymentStatus, error: String, deviceUDID: String) async -> String {
        do {
            let readiness = try await DeviceReadinessCommand().execute(deviceUDID: deviceUDID)
            return formatPipelineFailure(stage: stage, error: error, readiness: readiness)
        } catch {
            return """
            Deployment failed at stage: \(stage.description)
            Timestamp: \(ISO8601DateFormatter().string(from: Date()))
            Error Details: \(error)
            Detected Device State: readiness could not be probed: \(error.localizedDescription)
            Suggested Action: Connect the device again, unlock it, and run Check Trust & Developer Mode before retrying the deployment.
            """
        }
    }
}

public struct LogParser {
    public static func parseLogLine(_ line: String, type: DeviceLog.LogType) -> DeviceLog {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        var severity: DeviceLog.Severity = .info

        let lower = trimmed.lowercased()
        if lower.contains("[error]") || lower.contains("error:") || lower.contains("fail") {
            severity = .error
        } else if lower.contains("[warning]") || lower.contains("warning:") || lower.contains("warn") {
            severity = .warning
        } else if lower.contains("[debug]") || lower.contains("debug:") {
            severity = .debug
        }

        var category = "General"
        if trimmed.hasPrefix("[") {
            if let endIdx = trimmed.firstIndex(of: "]") {
                category = String(trimmed[trimmed.index(after: trimmed.startIndex)..<endIdx])
            }
        }

        return DeviceLog(
            timestamp: Date(),
            type: type,
            severity: severity,
            message: trimmed,
            subsystem: "com.swiftcode.deviceconnect",
            category: category
        )
    }
}

public struct OutputFormatter {
    public static func stripANSIColorCodes(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "\\x1b\\[[0-9;]*[mK]", options: []) else {
            return text
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
    }

    public static func formatBytes(_ bytes: Double) -> String {
        let kb = bytes / 1024
        let mb = kb / 1024
        let gb = mb / 1024

        if gb >= 1 {
            return String(format: "%.2f GB", gb)
        } else if mb >= 1 {
            return String(format: "%.1f MB", mb)
        } else {
            return String(format: "%.0f KB", kb)
        }
    }
}

public struct ProcessUtilities {
    public static func findExecutable(name: String) -> URL? {
        let paths = ["/usr/bin", "/usr/local/bin", "/usr/sbin", "/bin", "/sbin", "/Library/Apple/usr/bin"]
        let fm = FileManager.default

        for path in paths {
            let url = URL(fileURLWithPath: path).appendingPathComponent(name)
            if fm.isExecutableFile(atPath: url.path) {
                return url
            }
        }

        return nil
    }

    public static func cleanEnv() -> [String: String] {
        var baseEnv = ProcessInfo.processInfo.environment
        baseEnv.removeValue(forKey: "SWIFT_UPSTREAM_BUILD")
        return baseEnv
    }
}
