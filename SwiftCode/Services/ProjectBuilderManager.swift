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
        let projectDir = project.directoryURL
        if hasXcodeProjectFiles(in: projectDir) {
            return
        }

        generateXcodeProjectFiles(in: projectDir, projectName: project.name)
    }

    func prepareXcodeFilesForImport(projectDir: URL, projectName: String) {
        if hasXcodeProjectFiles(in: projectDir) {
            return
        }

        generateXcodeProjectFiles(in: projectDir, projectName: projectName)
    }

    @MainActor
    func updateProjectFiles(for project: Project) {
        let projectDir = project.directoryURL
        if hasXcodeProjectFiles(in: projectDir) {
            return
        }

        generateXcodeProjectFiles(in: projectDir, projectName: project.name)
    }

    // MARK: - Detection

    func hasXcodeProjectFiles(in directory: URL) -> Bool {
        guard let contents = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else { return false }

        return contents.contains {
            $0.pathExtension == "xcodeproj" || $0.pathExtension == "xcworkspace"
        }
    }

    // MARK: - Generation

    private func generateXcodeProjectFiles(in projectDir: URL, projectName: String) {
        do {
            try ensureSubdirectories(in: projectDir)

            let localBuildingDir = try ensureLocalBuildingDirectory()
            let generatedDir = localBuildingDir.appendingPathComponent("Generated")
            try fm.createDirectory(at: generatedDir, withIntermediateDirectories: true)

            let infoPlistURL = generatedDir.appendingPathComponent("Info.plist")
            try ensureInfoPlist(at: infoPlistURL, bundleName: projectName)

            let swiftSources = collectSwiftFiles(in: projectDir)
            let projectYAMLURL = localBuildingDir.appendingPathComponent("project.yml")
            let yaml = makeProjectYAML(
                projectName: projectName,
                projectDir: projectDir,
                localBuildingDir: localBuildingDir,
                infoPlistURL: infoPlistURL,
                swiftSourceFiles: swiftSources
            )
            try yaml.write(to: projectYAMLURL, atomically: true, encoding: .utf8)

            try runXcodeGen(specURL: projectYAMLURL, projectRoot: projectDir)
            try writeXcworkspaceIfNeeded(in: projectDir, projectName: projectName)
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

    private func ensureLocalBuildingDirectory() throws -> URL {
        let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
        let localBuildingDir = cwd
            .appendingPathComponent("SwiftCode")
            .appendingPathComponent("Backend")
            .appendingPathComponent("Local Building")

        if !fm.fileExists(atPath: localBuildingDir.path) {
            try fm.createDirectory(at: localBuildingDir, withIntermediateDirectories: true)
        }

        return localBuildingDir
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
    <key>UILaunchStoryboardName</key>
    <string></string>
    <key>UIApplicationSceneManifest</key>
    <dict/>
    <key>UIApplicationSupportsIndirectInputEvents</key>
    <true/>
    <key>UILaunchScreen</key>
    <dict/>
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
        localBuildingDir: URL,
        infoPlistURL: URL,
        swiftSourceFiles: [String]
    ) -> String {
        let sourceEntries: [String]

        if swiftSourceFiles.isEmpty {
            sourceEntries = ["Sources", "Views", "Features"].map {
                "      - \(relativePath(from: localBuildingDir, to: projectDir.appendingPathComponent($0)))"
            }
        } else {
            sourceEntries = swiftSourceFiles.map {
                "      - \(relativePath(from: localBuildingDir, to: projectDir.appendingPathComponent($0)))"
            }
        }

        let plistRelative = relativePath(from: projectDir, to: infoPlistURL)

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
\(sourceEntries.joined(separator: "\n"))
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.swiftcode.userproject
        INFOPLIST_FILE: \(plistRelative)
"""
    }

    private func runXcodeGen(specURL: URL, projectRoot: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "xcodegen",
            "generate",
            "--spec", specURL.path,
            "--project", projectRoot.path,
        ]

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

    private func writeXcworkspaceIfNeeded(in projectDir: URL, projectName: String) throws {
        let workspaceURL = projectDir.appendingPathComponent("\(projectName).xcworkspace")
        if fm.fileExists(atPath: workspaceURL.path) {
            return
        }

        let dataURL = workspaceURL.appendingPathComponent("contents.xcworkspacedata")
        try fm.createDirectory(at: workspaceURL, withIntermediateDirectories: true)

        let xml = """
<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "group:\(projectName).xcodeproj">
   </FileRef>
</Workspace>
"""
        try xml.write(to: dataURL, atomically: true, encoding: .utf8)
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
