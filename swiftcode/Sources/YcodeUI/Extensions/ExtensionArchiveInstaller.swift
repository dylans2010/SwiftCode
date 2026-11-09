import Foundation
import SwiftCodeExtensions
import SwiftCodeSDK
import YcodeSubprocess












public enum ExtensionArchiveInstaller {
    public enum InstallError: LocalizedError {
        case notAnExtensionArchive
        case missingManifest(String)
        case unsafeIdentifier(String)

        public var errorDescription: String? {
            switch self {
            case .notAnExtensionArchive:
                return "The selected file is not a recognized extension archive (expected a VSIX with extension/package.json or a .swiftcode-extension with swiftcode.json)."
            case .missingManifest(let name):
                return "The archive is missing '\(name)'."
            case .unsafeIdentifier(let id):
                return "The extension identifier '\(id)' is not safe to use as an install directory name."
            }
        }
    }

    
    
    @discardableResult
    public static func install(fileURL: URL) async throws -> String {
        let staging = FileManager.default.temporaryDirectory
            .appendingPathComponent("swiftcode-ext-install-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: staging) }
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        try await extract(archive: fileURL, into: staging)

        let vsixManifest = staging.appendingPathComponent("extension/package.json")
        if FileManager.default.fileExists(atPath: vsixManifest.path) {
            return try await installVSIX(at: fileURL, manifestURL: vsixManifest)
        }
        let sdkManifest = staging.appendingPathComponent("swiftcode.json")
        if FileManager.default.fileExists(atPath: sdkManifest.path) {
            return try await installSwiftCodePackage(from: staging, archive: fileURL)
        }
        throw InstallError.notAnExtensionArchive
    }

    

    private static func installVSIX(at fileURL: URL, manifestURL: URL) async throws -> String {
        let manifest = try VSCodeManifestParser.parseFile(at: manifestURL)
        try await ExtensionManager.shared.installLocalVSIX(at: fileURL, identity: manifest.identity)
        return "Installed \(manifest.metadata.displayName) \(manifest.metadata.version)."
    }

    

    private static func installSwiftCodePackage(from staging: URL, archive: URL) async throws -> String {
        let manifestURL = staging.appendingPathComponent("swiftcode.json")
        let manifest: SwiftCodeManifest
        do {
            manifest = try SwiftCodeManifestValidator.validate(data: Data(contentsOf: manifestURL))
        } catch {
            throw InstallError.missingManifest("a valid swiftcode.json (\(error.localizedDescription))")
        }
        guard manifest.type == "extension" else {
            throw SwiftCodeExtensionError.package("The archive's swiftcode.json does not describe an extension package.")
        }
        try PackageService.validateSwiftCodePackage(at: staging, manifest: manifest)
        try validatePathComponent(manifest.id)
        try validatePathComponent(manifest.version)

        let versionDir = SDKExtensionRegistry.extensionsRoot
            .appendingPathComponent(manifest.id, isDirectory: true)
            .appendingPathComponent(manifest.version, isDirectory: true)
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: versionDir.path) {
            try fileManager.removeItem(at: versionDir)
        }
        try fileManager.createDirectory(at: versionDir, withIntermediateDirectories: true)
        for item in try fileManager.contentsOfDirectory(atPath: staging.path) {
            try fileManager.moveItem(
                at: staging.appendingPathComponent(item),
                to: versionDir.appendingPathComponent(item))
        }

        let digest = try await SDKExtensionRegistry.shared.computeDigest(of: versionDir)
        let now = Date()
        let record = SDKInstalledExtension(
            id: manifest.id, name: manifest.name, version: manifest.version,
            packageDigest: digest, installPath: versionDir,
            installedAt: now, updatedAt: now, enabled: true, manifest: manifest)
        try await SDKExtensionRegistry.shared.recordInstall(record)
        await SDKExtensionRegistry.shared.scan()
        return "Installed \(manifest.name) \(manifest.version) from \(archive.lastPathComponent)."
    }

    private static func validatePathComponent(_ component: String) throws {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        guard !component.isEmpty, component.count <= 128,
              component.unicodeScalars.allSatisfy({ allowed.contains($0) }),
              !component.hasPrefix("."), !component.contains("..") else {
            throw InstallError.unsafeIdentifier(component)
        }
    }

    

    private static func extract(archive: URL, into staging: URL) async throws {
        let output: Subprocess.Output
        do {
            output = try await Task.detached {
                try Subprocess.run("/usr/bin/ditto", ["-x", "-k", archive.path, staging.path])
            }.value
        } catch {
            throw SwiftCodeExtensionError.package("Could not extract the archive: \(error.localizedDescription)")
        }
        guard output.status == 0 else {
            throw SwiftCodeExtensionError.package(
                "Archive extraction failed: \(output.stderrText.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
    }
}
