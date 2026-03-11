import Foundation

// MARK: - ProjectBuilderManager

/// Manages generation of user-project build files via XcodeGen.
/// SwiftCode's own project files are not modified.
final class ProjectBuilderManager {
    static let shared = ProjectBuilderManager()
    private init() {}

    private let fm = FileManager.default

    // MARK: - Public Entry Points

    @MainActor
    func prepareXcodeFiles(for project: Project) {
        prepareXcodeFiles(projectDir: project.directoryURL, projectName: project.name)
    }

    func prepareXcodeFilesForImport(projectDir: URL, projectName: String) {
        prepareXcodeFiles(projectDir: projectDir, projectName: projectName)
    }

    @MainActor
    func updateProjectFiles(for project: Project) {
        prepareXcodeFiles(projectDir: project.directoryURL, projectName: project.name)
    }

    func hasXcodeProjectFiles(in directory: URL) -> Bool {
        guard let contents = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else { return false }

        return contents.contains { $0.pathExtension == "xcodeproj" }
    }

    func hasBuildArtifacts(in projectDir: URL, projectName: String) -> Bool {
        let xcodeProj = projectDir.appendingPathComponent("\(projectName).xcodeproj")
        let workspace = projectDir.appendingPathComponent("\(projectName).xcworkspace")

        if fm.fileExists(atPath: xcodeProj.path), fm.fileExists(atPath: workspace.path) {
            return true
        }

        // Xcode always stores an internal workspace within the project bundle.
        let internalWorkspace = xcodeProj
            .appendingPathComponent("project.xcworkspace")
            .appendingPathComponent("contents.xcworkspacedata")
        return fm.fileExists(atPath: xcodeProj.path) && fm.fileExists(atPath: internalWorkspace.path)
    }

    // MARK: - Generation

    private func prepareXcodeFiles(projectDir: URL, projectName: String) {
        guard !hasBuildArtifacts(in: projectDir, projectName: projectName) else { return }

        do {
            try ensureSubdirectories(in: projectDir)

            let generatedDir = projectDir.appendingPathComponent("Generated")
            try fm.createDirectory(at: generatedDir, withIntermediateDirectories: true)

            let infoPlistURL = generatedDir.appendingPathComponent("Info.plist")
            try ensureInfoPlist(at: infoPlistURL, bundleName: projectName)

            let swiftSources = collectSwiftFiles(in: projectDir)
            let projectYAMLURL = projectDir.appendingPathComponent("project.yml")
            let yaml = makeProjectYAML(
                projectName: projectName,
                projectDir: projectDir,
                infoPlistURL: infoPlistURL,
                swiftSourceFiles: swiftSources
            )
            try yaml.write(to: projectYAMLURL, atomically: true, encoding: .utf8)

            try runXcodeGen(in: projectDir)
        } catch {
            print("ProjectBuilderManager generation failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private func ensureSubdirectories(in projectDir: URL) throws {
        for sub in ["Sources", "Views", "Features"] {
            let dir = projectDir.appendingPathComponent(sub)
            if !fm.fileExists(atPath: dir.path) {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
    }

    private func ensureInfoPlist(at url: URL, bundleName: String) throws {
        guard !fm.fileExists(atPath: url.path) else { return }

        let plist = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>\(bundleName)</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>UIApplicationSupportsIndirectInputEvents</key>
    <true/>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>UISupportedInterfaceOrientations~ipad</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationPortraitUpsideDown</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
</dict>
</plist>
"""

        try plist.write(to: url, atomically: true, encoding: .utf8)
    }

    private func makeProjectYAML(
        projectName: String,
        projectDir: URL,
        infoPlistURL: URL,
        swiftSourceFiles: [String]
    ) -> String {
        let sourceEntries = swiftSourceFiles.isEmpty
            ? ["Sources", "Views", "Features"]
            : swiftSourceFiles

        let sourceLines = sourceEntries.map { "      - \($0)" }.joined(separator: "\n")
        let plistRelative = relativePath(from: projectDir, to: infoPlistURL)
        let safeBundle = bundleIdentifierSuffix(for: projectName)

        return """
name: \(projectName)

options:
  bundleIdPrefix: com.swiftcode.userproject
  deploymentTarget:
    iOS: "16.0"

settings:
  base:
    SWIFT_VERSION: 5.0
    IPHONEOS_DEPLOYMENT_TARGET: 16.0
    TARGETED_DEVICE_FAMILY: "1,2"

configs:
  Debug: debug
  Release: release

targets:
  \(projectName):
    type: application
    platform: iOS
    deploymentTarget: "16.0"
    sources:
\(sourceLines)
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.swiftcode.userproject.\(safeBundle)
        INFOPLIST_FILE: \(plistRelative)
"""
    }

    private func runXcodeGen(in projectRoot: URL) throws {
        let process = Process()
        process.currentDirectoryURL = projectRoot
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["xcodegen", "generate", "--spec", "project.yml"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? "Unknown XcodeGen error"
            throw NSError(domain: "ProjectBuilderManager", code: Int(process.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: "XcodeGen failed: \(output)",
            ])
        }
    }

    // MARK: - File Collection

    private func collectSwiftFiles(in projectDir: URL) -> [String] {
        var allFiles: [String] = []
        for folder in ["Sources", "Views", "Features"] {
            let folderURL = projectDir.appendingPathComponent(folder)
            allFiles += collectSwiftFilesRecursively(in: folderURL, relativeTo: projectDir)
        }
        return allFiles.sorted()
    }

    private func collectSwiftFilesRecursively(in directory: URL, relativeTo base: URL) -> [String] {
        guard fm.fileExists(atPath: directory.path),
              let contents = try? fm.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: .skipsHiddenFiles
              )
        else { return [] }

        var results: [String] = []
        let basePath = base.standardizedFileURL.path

        for item in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

            if isDir {
                results += collectSwiftFilesRecursively(in: item, relativeTo: base)
            } else if item.pathExtension == "swift" {
                let fullPath = item.standardizedFileURL.path
                if fullPath.hasPrefix(basePath + "/") {
                    results.append(String(fullPath.dropFirst(basePath.count + 1)))
                }
            }
        }

        return results
    }

    private func bundleIdentifierSuffix(for projectName: String) -> String {
        let lowered = projectName.lowercased()
        let cleaned = lowered.map { char -> Character in
            if char.isLetter || char.isNumber {
                return char
            }
            return "-"
        }
        let collapsed = String(cleaned)
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
        return collapsed.isEmpty ? "app" : collapsed
    }

    private func relativePath(from base: URL, to target: URL) -> String {
        let baseComponents = base.standardizedFileURL.pathComponents
        let targetComponents = target.standardizedFileURL.pathComponents

        var commonIndex = 0
        while commonIndex < min(baseComponents.count, targetComponents.count),
              baseComponents[commonIndex] == targetComponents[commonIndex] {
            commonIndex += 1
        }

        let upMoves = Array(repeating: "..", count: max(0, baseComponents.count - commonIndex))
        let downMoves = Array(targetComponents.dropFirst(commonIndex))
        let pathParts = upMoves + downMoves

        return pathParts.isEmpty ? "." : NSString.path(withComponents: pathParts)
    }
}
