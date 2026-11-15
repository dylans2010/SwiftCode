import Foundation
import YcodeDeviceModel

public enum DeviceUtilitiesError: Error, LocalizedError, Sendable {
    case invalidDeviceIdentifier(String)
    case invalidURL(String)
    case invalidBundleID(String)
    case invalidPayload(String)
    case payloadNeedsTargetBundle
    case sourceFileMissing(String)
    case sourceIsDirectory(String)
    case containerPathMissing(bundleID: String)
    case invalidContainerPath(String)
    case containerFileMissing(String)
    case invalidContainerRelativePath(String)
    case invalidDestinationFileName(String)
    case fileOperationFailed(String)
    case simctlFailed(String)
    case orientationUnsupported(reason: String)

    public var errorDescription: String? {
        switch self {
        case .invalidDeviceIdentifier(let value):
            return "Invalid simulator identifier: '\(value)'. Pass a UDID, a device name, or booted."
        case .invalidURL(let value):
            return "Invalid URL: '\(value)'. Enter a complete URL including its scheme."
        case .invalidBundleID(let value):
            return "Invalid bundle identifier: '\(value)'. Use a reverse-DNS identifier such as com.example.app."
        case .invalidPayload(let message):
            return message
        case .payloadNeedsTargetBundle:
            return "No bundle identifier was given and the payload has no Simulator Target Bundle key. Provide a bundle identifier or add Simulator Target Bundle to the payload."
        case .sourceFileMissing(let path):
            return "File not found: \(path)"
        case .sourceIsDirectory(let path):
            return "Expected a file but found a folder: \(path)"
        case .containerPathMissing(let bundleID):
            return "simctl get_app_container returned no container path for '\(bundleID)'. Check that the app is installed on the simulator."
        case .invalidContainerPath(let output):
            return "simctl get_app_container printed an unusable container path: '\(output)'"
        case .containerFileMissing(let path):
            return "No file at '\(path)' inside the app container."
        case .invalidContainerRelativePath(let path):
            return "Invalid path inside the app container: '\(path)'. Use a relative path such as Documents/report.json, without .. segments."
        case .invalidDestinationFileName(let name):
            return "Invalid destination file name: '\(name)'"
        case .fileOperationFailed(let message):
            return message
        case .simctlFailed(let message):
            return message
        case .orientationUnsupported(let reason):
            return "Orientation is not supported: \(reason)"
        }
    }
}

public enum SimulatorOrientation: String, CaseIterable, Sendable {
    case portrait
    case landscapeLeft
    case landscapeRight
    case portraitUpsideDown

    public var displayName: String {
        switch self {
        case .portrait: return "Portrait"
        case .landscapeLeft: return "Landscape Left"
        case .landscapeRight: return "Landscape Right"
        case .portraitUpsideDown: return "Portrait Upside Down"
        }
    }
}

public enum DeviceOrientationSupport: Sendable {
    case unsupported(reason: String)
}

public actor DeviceUtilities {
    public static let xcrunPath = "/usr/bin/xcrun"
    public static let maximumPushPayloadBytes = 4096
    public static let orientationUnavailableReason = "simctl exposes no command that changes a simulator orientation. Rotate the simulator from the Simulator or Device Hub window, or set XCUIDevice orientation inside a UI test."

    public static var orientationSupport: DeviceOrientationSupport {
        .unsupported(reason: orientationUnavailableReason)
    }

    public init() {}

    public static func validatedDeviceIdentifier(_ raw: String) throws -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("\0") else {
            throw DeviceUtilitiesError.invalidDeviceIdentifier(raw)
        }
        return trimmed
    }

    public static func validatedURL(_ raw: String) throws -> URL {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DeviceUtilitiesError.invalidURL(raw)
        }
        guard trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            throw DeviceUtilitiesError.invalidURL(raw)
        }
        guard let url = URL(string: trimmed), let scheme = url.scheme, !scheme.isEmpty else {
            throw DeviceUtilitiesError.invalidURL(raw)
        }
        return url
    }

    public static func openURLArguments(udid: String, url: URL) -> [String] {
        ["simctl", "openurl", udid, url.absoluteString]
    }

    public static func validatedBundleID(_ raw: String) throws -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DeviceUtilitiesError.invalidBundleID(raw)
        }
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-.")
        guard trimmed.rangeOfCharacter(from: allowed.inverted) == nil else {
            throw DeviceUtilitiesError.invalidBundleID(raw)
        }
        guard trimmed.contains("."), !trimmed.hasPrefix("."), !trimmed.hasSuffix("."), !trimmed.contains("..") else {
            throw DeviceUtilitiesError.invalidBundleID(raw)
        }
        return trimmed
    }

    public static func validatedPushPayload(_ data: Data, bundleID: String?) throws {
        guard data.count <= maximumPushPayloadBytes else {
            throw DeviceUtilitiesError.invalidPayload("Push payload is \(data.count) bytes; simctl accepts at most \(maximumPushPayloadBytes) bytes.")
        }
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            throw DeviceUtilitiesError.invalidPayload("Push payload is not valid JSON: \(error.localizedDescription)")
        }
        guard let payload = object as? [String: Any] else {
            throw DeviceUtilitiesError.invalidPayload("Push payload must be a JSON object at the top level.")
        }
        guard payload["aps"] != nil else {
            throw DeviceUtilitiesError.invalidPayload("Push payload must contain an aps key.")
        }
        if bundleID == nil {
            guard let target = payload["Simulator Target Bundle"] as? String, !target.isEmpty else {
                throw DeviceUtilitiesError.payloadNeedsTargetBundle
            }
        }
    }

    public static func pushArguments(udid: String, bundleID: String?, payloadPath: String) -> [String] {
        if let bundleID {
            return ["simctl", "push", udid, bundleID, payloadPath]
        }
        return ["simctl", "push", udid, payloadPath]
    }

    public static func appContainerArguments(udid: String, bundleID: String) -> [String] {
        ["simctl", "get_app_container", udid, bundleID, "data"]
    }

    public static func parsedContainerPath(_ stdout: String) throws -> String {
        let trimmed = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.hasPrefix("/") else {
            throw DeviceUtilitiesError.invalidContainerPath(stdout)
        }
        return trimmed
    }

    public static func containerDocumentsPath(containerPath: String, fileName: String) throws -> String {
        let trimmed = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != ".", trimmed != "..", !trimmed.contains("/") else {
            throw DeviceUtilitiesError.invalidDestinationFileName(fileName)
        }
        return containerPath + "/Documents/" + trimmed
    }

    public static func containerFilePath(containerPath: String, relativePath: String) throws -> String {
        let trimmed = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("/") else {
            throw DeviceUtilitiesError.invalidContainerRelativePath(relativePath)
        }
        let components = trimmed.split(separator: "/").map(String.init)
        guard !components.isEmpty, !components.contains("..") else {
            throw DeviceUtilitiesError.invalidContainerRelativePath(relativePath)
        }
        return containerPath + "/" + trimmed
    }

    public static func samplePushPayload(bundleID: String) -> String {
        let target = bundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "com.example.app" : bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        return """
        {
          "Simulator Target Bundle": "\(target)",
          "aps": {
            "alert": "Hello from SwiftCode",
            "sound": "default",
            "badge": 1
          }
        }
        """
    }

    public func openURL(udid: String, urlString: String) async throws {
        let device = try Self.validatedDeviceIdentifier(udid)
        let url = try Self.validatedURL(urlString)
        let result = try await runSimctl(Self.openURLArguments(udid: device, url: url), timeout: 15)
        guard result.exitCode == 0 else {
            throw DeviceUtilitiesError.simctlFailed(Self.simctlFailureMessage(result))
        }
    }

    public func sendPushNotification(udid: String, bundleID: String?, payloadFileURL: URL) async throws -> String {
        let device = try Self.validatedDeviceIdentifier(udid)
        let validatedBundleID: String?
        if let bundleID {
            validatedBundleID = try Self.validatedBundleID(bundleID)
        } else {
            validatedBundleID = nil
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: payloadFileURL.path, isDirectory: &isDirectory) else {
            throw DeviceUtilitiesError.sourceFileMissing(payloadFileURL.path)
        }
        guard !isDirectory.boolValue else {
            throw DeviceUtilitiesError.sourceIsDirectory(payloadFileURL.path)
        }
        let data: Data
        do {
            data = try Data(contentsOf: payloadFileURL)
        } catch {
            throw DeviceUtilitiesError.fileOperationFailed("Could not read payload file \(payloadFileURL.path): \(error.localizedDescription)")
        }
        try Self.validatedPushPayload(data, bundleID: validatedBundleID)
        let result = try await runSimctl(Self.pushArguments(udid: device, bundleID: validatedBundleID, payloadPath: payloadFileURL.path), timeout: 20)
        guard result.exitCode == 0 else {
            throw DeviceUtilitiesError.simctlFailed(Self.simctlFailureMessage(result))
        }
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func sendPushNotification(udid: String, bundleID: String?, payloadJSON: String) async throws -> String {
        guard let data = payloadJSON.data(using: .utf8) else {
            throw DeviceUtilitiesError.invalidPayload("Push payload text is not valid UTF-8.")
        }
        let validatedBundleID: String?
        if let bundleID {
            validatedBundleID = try Self.validatedBundleID(bundleID)
        } else {
            validatedBundleID = nil
        }
        try Self.validatedPushPayload(data, bundleID: validatedBundleID)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("swiftcode-push-\(UUID().uuidString).apns")
        do {
            try data.write(to: tempURL, options: [.atomic])
        } catch {
            throw DeviceUtilitiesError.fileOperationFailed("Could not write temporary payload file: \(error.localizedDescription)")
        }
        defer { try? FileManager.default.removeItem(at: tempURL) }
        return try await sendPushNotification(udid: udid, bundleID: validatedBundleID, payloadFileURL: tempURL)
    }

    public func appContainerPath(udid: String, bundleID: String) async throws -> String {
        let device = try Self.validatedDeviceIdentifier(udid)
        let validatedBundleID = try Self.validatedBundleID(bundleID)
        let result = try await runSimctl(Self.appContainerArguments(udid: device, bundleID: validatedBundleID), timeout: 15)
        guard result.exitCode == 0 else {
            throw DeviceUtilitiesError.simctlFailed(Self.simctlFailureMessage(result))
        }
        return try Self.parsedContainerPath(result.stdout)
    }

    public func pushFile(udid: String, bundleID: String, localFileURL: URL, destinationFileName: String? = nil) async throws -> URL {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: localFileURL.path, isDirectory: &isDirectory) else {
            throw DeviceUtilitiesError.sourceFileMissing(localFileURL.path)
        }
        guard !isDirectory.boolValue else {
            throw DeviceUtilitiesError.sourceIsDirectory(localFileURL.path)
        }
        let fileName: String
        if let destinationFileName {
            fileName = destinationFileName
        } else {
            fileName = localFileURL.lastPathComponent
        }
        let container = try await appContainerPath(udid: udid, bundleID: bundleID)
        let destinationPath = try Self.containerDocumentsPath(containerPath: container, fileName: fileName)
        let destinationURL = URL(fileURLWithPath: destinationPath)
        do {
            try FileManager.default.copyItem(at: localFileURL, to: destinationURL)
        } catch {
            throw DeviceUtilitiesError.fileOperationFailed("Could not copy \(localFileURL.path) into the simulator container: \(error.localizedDescription)")
        }
        let sourceSize = try fileSize(at: localFileURL)
        let destinationSize = try fileSize(at: destinationURL)
        guard sourceSize == destinationSize else {
            throw DeviceUtilitiesError.fileOperationFailed("Copied file size \(destinationSize) does not match source size \(sourceSize).")
        }
        return destinationURL
    }

    public func pullFile(udid: String, bundleID: String, containerRelativePath: String, destinationURL: URL) async throws -> URL {
        let container = try await appContainerPath(udid: udid, bundleID: bundleID)
        let sourcePath = try Self.containerFilePath(containerPath: container, relativePath: containerRelativePath)
        let sourceURL = URL(fileURLWithPath: sourcePath)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: sourcePath, isDirectory: &isDirectory) else {
            throw DeviceUtilitiesError.containerFileMissing(containerRelativePath)
        }
        guard !isDirectory.boolValue else {
            throw DeviceUtilitiesError.sourceIsDirectory(sourcePath)
        }
        let parent = destinationURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true, attributes: nil)
        } catch {
            throw DeviceUtilitiesError.fileOperationFailed("Could not create destination folder \(parent.path): \(error.localizedDescription)")
        }
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            do {
                try FileManager.default.removeItem(at: destinationURL)
            } catch {
                throw DeviceUtilitiesError.fileOperationFailed("Could not replace existing file at \(destinationURL.path): \(error.localizedDescription)")
            }
        }
        do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        } catch {
            throw DeviceUtilitiesError.fileOperationFailed("Could not copy \(sourcePath) to \(destinationURL.path): \(error.localizedDescription)")
        }
        let sourceSize = try fileSize(at: sourceURL)
        let destinationSize = try fileSize(at: destinationURL)
        guard sourceSize == destinationSize else {
            throw DeviceUtilitiesError.fileOperationFailed("Pulled file size \(destinationSize) does not match container file size \(sourceSize).")
        }
        return destinationURL
    }

    public func setOrientation(_ orientation: SimulatorOrientation, udid: String) async throws {
        _ = try Self.validatedDeviceIdentifier(udid)
        _ = orientation
        throw DeviceUtilitiesError.orientationUnsupported(reason: Self.orientationUnavailableReason)
    }

    private func runSimctl(_ arguments: [String], timeout: TimeInterval) async throws -> DeviceConnectProcessResult {
        do {
            return try await DeviceConnectProcessRunner.shared.run(
                executableURL: URL(fileURLWithPath: Self.xcrunPath),
                arguments: arguments,
                timeout: timeout
            )
        } catch {
            throw DeviceUtilitiesError.simctlFailed(error.localizedDescription)
        }
    }

    private static func simctlFailureMessage(_ result: DeviceConnectProcessResult) -> String {
        let detail = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if !detail.isEmpty {
            return "simctl exited with code \(result.exitCode): \(detail)"
        }
        let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if !output.isEmpty {
            return "simctl exited with code \(result.exitCode): \(output)"
        }
        return "simctl exited with code \(result.exitCode) and printed no output."
    }

    private func fileSize(at url: URL) throws -> Int {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard let size = attributes[.size] as? NSNumber else {
                throw DeviceUtilitiesError.fileOperationFailed("Could not read the size of \(url.path).")
            }
            return size.intValue
        } catch let error as DeviceUtilitiesError {
            throw error
        } catch {
            throw DeviceUtilitiesError.fileOperationFailed("Could not read the size of \(url.path): \(error.localizedDescription)")
        }
    }
}
