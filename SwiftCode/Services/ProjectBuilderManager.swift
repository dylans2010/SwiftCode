import XcodeProj
import PathKit
import Foundation

// MARK: - ProjectBuilderManager

/// Manages the automatic generation and maintenance of Xcode build files
/// (.xcodeproj and .xcworkspace) for SwiftCode projects.
///
/// Responsibilities:
/// - Generate `.xcodeproj` and `.xcworkspace` when a project is created or opened.
/// - Skip generation if existing files are already present (e.g. after ZIP import).
/// - Update the project structure when source files change.
/// - Preserve existing project metadata whenever possible.
final class ProjectBuilderManager {
    static let shared = ProjectBuilderManager()
    private init() {}

    private let fm = FileManager.default

    // MARK: - Public Entry Points

    /// Call this when a project is created or opened.
    /// Scans for existing Xcode project files; only generates new ones if none are found.
    /// - Parameter project: The SwiftCode project to process.
    @MainActor
    func prepareXcodeFiles(for project: Project) {
        prepareXcodeFilesInternal(projectDir: project.directoryURL, projectName: project.name)
    }

    /// Call this when a ZIP-imported project directory has been set up.
    /// Applies the same rules: skip generation if `.xcodeproj`/`.xcworkspace` already exist.
    /// - Parameters:
    ///   - projectDir: The root directory of the imported project.
    ///   - projectName: The name used for the generated project files.
    func prepareXcodeFilesForImport(projectDir: URL, projectName: String) {
        prepareXcodeFilesInternal(projectDir: projectDir, projectName: projectName)
    }

    /// Internal helper to handle project preparation using XcodeGen with a legacy fallback.
    private func prepareXcodeFilesInternal(projectDir: URL, projectName: String) {
        let xcodeProj = generatedXcodeProjPath(for: projectName)
        let xcworkspace = generatedXcworkspacePath(for: projectName)

        if hasXcodeProjectFiles(in: projectDir) || (fm.fileExists(atPath: xcodeProj.path) && fm.fileExists(atPath: xcworkspace.path)) {
            return
        }

        do {
            try ensureLocalBuildingDirectories()
            try generateProjectYaml(projectDir: projectDir, projectName: projectName)
            try ensureInfoPlist()
            try runXcodeGen()
        } catch {
            // Fallback to legacy generation if XcodeGen fails
            generateXcodeProjectFiles(in: projectDir, projectName: projectName)
        }
    }

    /// Ensures the Local Building and Generated directories exist.
    private func ensureLocalBuildingDirectories() throws {
        let localBuildingURL = getLocalBuildingURL()
        let generatedURL = localBuildingURL.appendingPathComponent("Generated")
        if !fm.fileExists(atPath: generatedURL.path) {
            try fm.createDirectory(at: generatedURL, withIntermediateDirectories: true)
        }
    }

    /// Call this when a user adds, removes, or renames files inside the project.
    /// Regenerates the source-file list inside the `.xcodeproj` so the target stays valid.
    /// - Parameter project: The SwiftCode project whose file tree changed.
    @MainActor
    func updateProjectFiles(for project: Project) {
        let projectDir = project.directoryURL
        let xcodeProjectDir = projectDir.appendingPathComponent("\(project.name).xcodeproj")
        guard fm.fileExists(atPath: xcodeProjectDir.path) else {
            // No project file yet — generate from scratch.
            generateXcodeProject(for: project)
            return
        }
        regenerateProjectPBX(in: xcodeProjectDir, projectDir: projectDir, projectName: project.name)
    }

    // MARK: - Detection

    /// Returns `true` when the directory already contains a `.xcodeproj` or `.xcworkspace`.
    func hasXcodeProjectFiles(in directory: URL) -> Bool {
        guard let contents = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else { return false }

        // If either exists: load and continue using the existing project configuration.
        return contents.contains {
            $0.pathExtension == "xcodeproj" || $0.pathExtension == "xcworkspace"
        }
    }

    // MARK: - Generation

    /// Generates both `.xcodeproj` and `.xcworkspace` for a SwiftCode project.
    @MainActor
    private func generateXcodeProject(for project: Project) {
        generateXcodeProjectFiles(in: project.directoryURL, projectName: project.name)
    }

    /// Generates the full Xcode project structure inside `projectDir`.
    private func generateXcodeProjectFiles(in projectDir: URL, projectName: String) {
        do {
            try ensureSubdirectories(in: projectDir)
            try buildAndWriteXcodeProject(in: projectDir, projectName: projectName)
            try writeXcworkspace(in: projectDir, projectName: projectName)
        } catch {
            // Generation is best-effort; failures are non-fatal.
        }
    }

    // MARK: - Subdirectory Scaffolding

    /// Ensures the expected source/asset subdirectories exist without overwriting any files.
    private func ensureSubdirectories(in projectDir: URL) throws {
        let subdirectories = ["Sources", "Views", "Features", "Assets"]
        for sub in subdirectories {
            let dir = projectDir.appendingPathComponent(sub)
            if !fm.fileExists(atPath: dir.path) {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
    }

    // MARK: - Xcode Project Generation using XcodeProj

    /// Generates a valid `.xcodeproj` bundle using the XcodeProj library.
    /// Creates an iOS application target with all detected Swift source files
    /// attached to the Compile Sources build phase.
    private func buildAndWriteXcodeProject(in projectDir: URL, projectName: String) throws {
        let xcodeProjectPath = Path(projectDir.appendingPathComponent("\(projectName).xcodeproj").path)

        // Preserve existing project if present.
        guard !xcodeProjectPath.exists else { return }

        let pbxproj = PBXProj()

        // Collect Swift source files
        let swiftFiles = collectSwiftFiles(in: projectDir, relativeTo: projectDir)

        // --- Build Configurations (project-level) ---
        let projectDebugConfig = XCBuildConfiguration(
            name: "Debug",
            buildSettings: [
                "ALWAYS_SEARCH_USER_PATHS": "NO",
                "IPHONEOS_DEPLOYMENT_TARGET": "16.0",
                "SWIFT_VERSION": "5.0",
            ]
        )
        let projectReleaseConfig = XCBuildConfiguration(
            name: "Release",
            buildSettings: [
                "ALWAYS_SEARCH_USER_PATHS": "NO",
                "IPHONEOS_DEPLOYMENT_TARGET": "16.0",
                "SWIFT_VERSION": "5.0",
            ]
        )
        pbxproj.add(object: projectDebugConfig)
        pbxproj.add(object: projectReleaseConfig)

        let projectConfigList = XCConfigurationList(
            buildConfigurations: [projectDebugConfig, projectReleaseConfig],
            defaultConfigurationName: "Release"
        )
        pbxproj.add(object: projectConfigList)

        // --- Groups ---
        // Ensure the directories exist first.
        try ensureSubdirectories(in: projectDir)

        let sourcesGroup = PBXGroup(children: [], sourceTree: .group, name: "Sources")
        let viewsGroup = PBXGroup(children: [], sourceTree: .group, name: "Views")
        let featuresGroup = PBXGroup(children: [], sourceTree: .group, name: "Features")
        let assetsGroup = PBXGroup(children: [], sourceTree: .group, name: "Assets")
        let productsGroup = PBXGroup(children: [], sourceTree: .group, name: "Products")

        pbxproj.add(object: sourcesGroup)
        pbxproj.add(object: viewsGroup)
        pbxproj.add(object: featuresGroup)
        pbxproj.add(object: assetsGroup)
        pbxproj.add(object: productsGroup)

        // --- File References & Build Files ---
        var buildFiles: [PBXBuildFile] = []
        for filePath in swiftFiles {
            let fileName = URL(fileURLWithPath: filePath).lastPathComponent

            // Determine target group based on path
            let targetGroup: PBXGroup

            if filePath.contains("Views/") {
                targetGroup = viewsGroup
            } else if filePath.contains("Features/") {
                targetGroup = featuresGroup
            } else {
                targetGroup = sourcesGroup
            }

            let fileRef = PBXFileReference(
                sourceTree: .group,
                name: fileName,
                lastKnownFileType: "sourcecode.swift",
                path: filePath
            )
            pbxproj.add(object: fileRef)
            targetGroup.children.append(fileRef)

            let buildFile = PBXBuildFile(file: fileRef)
            pbxproj.add(object: buildFile)
            buildFiles.append(buildFile)
        }

        // Add Assets if they exist
        let assetDirs = ["Assets.xcassets", "Assets"]
        for assetDir in assetDirs {
            if fm.fileExists(atPath: projectDir.appendingPathComponent(assetDir).path) {
                let assetRef = PBXFileReference(
                    sourceTree: .group,
                    name: assetDir,
                    lastKnownFileType: "folder.assetcatalog",
                    path: assetDir
                )
                pbxproj.add(object: assetRef)
                assetsGroup.children.append(assetRef)
                break
            }
        }

        // --- Product Reference ---
        let productRef = PBXFileReference(
            sourceTree: .buildProductsDir,
            explicitFileType: "wrapper.application",
            path: "\(projectName).app",
            includeInIndex: false
        )
        pbxproj.add(object: productRef)
        productsGroup.children.append(productRef)

        // --- Build Phases ---
        let sourcesBuildPhase = PBXSourcesBuildPhase(files: buildFiles)
        pbxproj.add(object: sourcesBuildPhase)

        let frameworksBuildPhase = PBXFrameworksBuildPhase(files: [])
        pbxproj.add(object: frameworksBuildPhase)

        // --- Target Build Configurations ---
        let bundleID = "com.swiftcode.\(projectName.replacingOccurrences(of: " ", with: "").lowercased())"
        let targetDebugConfig = XCBuildConfiguration(
            name: "Debug",
            buildSettings: [
                "IPHONEOS_DEPLOYMENT_TARGET": "16.0",
                "TARGETED_DEVICE_FAMILY": "1,2",
                "SWIFT_VERSION": "5.0",
                "PRODUCT_BUNDLE_IDENTIFIER": bundleID,
                "PRODUCT_NAME": "$(TARGET_NAME)",
                "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks",
                "GENERATE_INFOPLIST_FILE": "YES",
            ]
        )
        let targetReleaseConfig = XCBuildConfiguration(
            name: "Release",
            buildSettings: [
                "IPHONEOS_DEPLOYMENT_TARGET": "16.0",
                "TARGETED_DEVICE_FAMILY": "1,2",
                "SWIFT_VERSION": "5.0",
                "PRODUCT_BUNDLE_IDENTIFIER": bundleID,
                "PRODUCT_NAME": "$(TARGET_NAME)",
                "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks",
                "GENERATE_INFOPLIST_FILE": "YES",
            ]
        )
        pbxproj.add(object: targetDebugConfig)
        pbxproj.add(object: targetReleaseConfig)

        let targetConfigList = XCConfigurationList(
            buildConfigurations: [targetDebugConfig, targetReleaseConfig],
            defaultConfigurationName: "Release"
        )
        pbxproj.add(object: targetConfigList)

        // --- Native Target ---
        let target = PBXNativeTarget(
            name: projectName,
            buildConfigurationList: targetConfigList,
            buildPhases: [sourcesBuildPhase, frameworksBuildPhase],
            productName: projectName,
            product: productRef,
            productType: .application
        )
        pbxproj.add(object: target)

        // --- Main Group ---
        let mainGroup = PBXGroup(
            children: [sourcesGroup, viewsGroup, featuresGroup, assetsGroup, productsGroup],
            sourceTree: .group
        )
        pbxproj.add(object: mainGroup)

        // --- PBXProject ---
        let project = PBXProject(
            name: projectName,
            buildConfigurationList: projectConfigList,
            compatibilityVersion: "Xcode 14.0",
            mainGroup: mainGroup,
            targets: [target]
        )
        project.productRefGroup = productsGroup
        pbxproj.add(object: project)
        pbxproj.rootObject = project

        // --- Write .xcodeproj ---
        let xcodeProj = XcodeProj(workspace: XCWorkspace(), pbxproj: pbxproj)
        try xcodeProj.write(path: xcodeProjectPath)

        // --- Write shared scheme ---
        try writeXcscheme(
            in: projectDir.appendingPathComponent("\(projectName).xcodeproj"),
            projectName: projectName,
            targetUUID: target.uuid
        )
    }

    // MARK: - Regeneration

    /// Reloads an existing `.xcodeproj`, updates the Swift file references
    /// in the Sources group and Compile Sources build phase, then writes it back.
    private func regenerateProjectPBX(in xcodeProjectDir: URL, projectDir: URL, projectName: String) {
        do {
            let projectPath = Path(xcodeProjectDir.path)
            let xcodeProj = try XcodeProj(path: projectPath)
            let pbxproj = xcodeProj.pbxproj
            guard let rootProject = pbxproj.rootObject else { return }

            let swiftFiles = collectSwiftFiles(in: projectDir, relativeTo: projectDir)

            // Locate the Sources group.
            guard let sourcesGroup = rootProject.mainGroup.children
                .compactMap({ $0 as? PBXGroup })
                .first(where: { $0.name == "Sources" })
            else { return }

            // Locate the native target and its sources build phase.
            guard let target = pbxproj.nativeTargets.first(where: { $0.name == projectName }),
                  let sourcesBuildPhase = try target.sourcesBuildPhase()
            else { return }

            // Remove old file references from group and build phase.
            for child in sourcesGroup.children {
                pbxproj.delete(object: child)
            }
            sourcesGroup.children.removeAll()

            if let oldBuildFiles = sourcesBuildPhase.files {
                for buildFile in oldBuildFiles {
                    pbxproj.delete(object: buildFile)
                }
            }
            sourcesBuildPhase.files?.removeAll()

            // Add updated file references and build files.
            for filePath in swiftFiles {
                let fileName = URL(fileURLWithPath: filePath).lastPathComponent
                let fileRef = PBXFileReference(
                    sourceTree: .group,
                    name: fileName,
                    lastKnownFileType: "sourcecode.swift",
                    path: filePath
                )
                pbxproj.add(object: fileRef)
                sourcesGroup.children.append(fileRef)

                let buildFile = PBXBuildFile(file: fileRef)
                pbxproj.add(object: buildFile)
                sourcesBuildPhase.files?.append(buildFile)
            }

            try xcodeProj.write(path: projectPath)
        } catch {
            // Regeneration failure is non-fatal.
        }
    }

    // MARK: - .xcscheme

    private func writeXcscheme(in xcodeProjectDir: URL, projectName: String, targetUUID: String) throws {
        let schemesDir = xcodeProjectDir
            .appendingPathComponent("xcshareddata")
            .appendingPathComponent("xcschemes")
        try fm.createDirectory(at: schemesDir, withIntermediateDirectories: true)

        let schemeURL = schemesDir.appendingPathComponent("\(projectName).xcscheme")
        guard !fm.fileExists(atPath: schemeURL.path) else { return }

        let scheme = """
<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1500"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "\(targetUUID)"
               BuildableName = "\(projectName).app"
               BlueprintName = "\(projectName)"
               ReferencedContainer = "container:\(projectName).xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "\(targetUUID)"
            BuildableName = "\(projectName).app"
            BlueprintName = "\(projectName)"
            ReferencedContainer = "container:\(projectName).xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "\(targetUUID)"
            BuildableName = "\(projectName).app"
            BlueprintName = "\(projectName)"
            ReferencedContainer = "container:\(projectName).xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""
        try scheme.write(to: schemeURL, atomically: true, encoding: .utf8)
    }

    // MARK: - .xcworkspace

    /// Creates the `.xcworkspace` bundle using PathKit, referencing the generated `.xcodeproj`.
    private func writeXcworkspace(in projectDir: URL, projectName: String) throws {
        let workspacePath = Path(projectDir.appendingPathComponent("\(projectName).xcworkspace").path)

        // Preserve existing workspace if present.
        guard !workspacePath.exists else { return }

        let workspaceData = XCWorkspaceData(children: [
            .file(.init(location: .group("\(projectName).xcodeproj")))
        ])
        let workspace = XCWorkspace(data: workspaceData)
        try workspace.write(path: workspacePath)

        // Inside create the file: contents.xcworkspacedata (Done by workspace.write)
    }

    // MARK: - XcodeGen Configuration

    /// Generates a `project.yml` file inside the Local Building folder.
    private func generateProjectYaml(projectDir: URL, projectName: String) throws {
        let localBuildingURL = getLocalBuildingURL()

        let projectPath = Path(projectDir.standardized.path)
        let buildingPath = Path(localBuildingURL.standardized.path)
        let relPath = projectPath.relative(to: buildingPath).string

        let sanitizedName = projectName.replacingOccurrences(of: " ", with: "")
        let bundleId = "com.swiftcode.\(sanitizedName.lowercased())"

        let yamlContent = """
name: \(projectName)

options:
  bundleIdPrefix: com.swiftcode.\(sanitizedName.lowercased())
  generateWorkspace: true
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
      - \(relPath)/Sources
      - \(relPath)/Views
      - \(relPath)/Features
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: \(bundleId)
        INFOPLIST_FILE: Generated/Info.plist
"""
        let yamlURL = localBuildingURL.appendingPathComponent("project.yml")
        try yamlContent.write(to: yamlURL, atomically: true, encoding: .utf8)
    }

    /// Returns the URL to the Local Building folder inside Documents.
    func getLocalBuildingURL() -> URL {
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("SwiftCode/Backend/Local Building")
    }

    /// Returns the expected path for the generated .xcodeproj.
    func generatedXcodeProjPath(for projectName: String) -> URL {
        getLocalBuildingURL().appendingPathComponent("\(projectName).xcodeproj")
    }

    /// Returns the expected path for the generated .xcworkspace.
    func generatedXcworkspacePath(for projectName: String) -> URL {
        getLocalBuildingURL().appendingPathComponent("\(projectName).xcworkspace")
    }

    /// Triggers XcodeGen to produce the project files.
    private func runXcodeGen() throws {
        #if os(macOS)
        let localBuildingURL = getLocalBuildingURL()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.currentDirectoryURL = localBuildingURL
        process.arguments = [
            "xcodegen",
            "--spec", "project.yml",
            "--project", "."
        ]

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw NSError(domain: "ProjectBuilderManager", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "XcodeGen failed with status \(process.terminationStatus)"])
        }
        #else
        // XcodeGen execution is only supported on macOS.
        // On iOS, this would typically be handled by a remote build service.
        throw NSError(domain: "ProjectBuilderManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "XcodeGen is only supported on macOS."])
        #endif
    }

    /// Automatically generates a minimal Info.plist if it does not exist.
    private func ensureInfoPlist() throws {
        let localBuildingURL = getLocalBuildingURL()
        let generatedDir = localBuildingURL.appendingPathComponent("Generated")
        if !fm.fileExists(atPath: generatedDir.path) {
            try fm.createDirectory(at: generatedDir, withIntermediateDirectories: true)
        }

        let infoPlistURL = generatedDir.appendingPathComponent("Info.plist")
        guard !fm.fileExists(atPath: infoPlistURL.path) else { return }

        let content = """
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
	<string>$(PRODUCT_NAME)</string>
	<key>CFBundlePackageType</key>
	<string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSRequiresIPhoneOS</key>
	<true/>
	<key>UIApplicationSceneManifest</key>
	<dict>
		<key>UIApplicationSupportsMultipleScenes</key>
		<true/>
	</dict>
	<key>UILaunchScreen</key>
	<dict/>
	<key>UISupportedInterfaceOrientations</key>
	<array>
		<string>UIInterfaceOrientationPortrait</string>
		<string>UIInterfaceOrientationLandscapeLeft</string>
		<string>UIInterfaceOrientationLandscapeRight</string>
	</array>
</dict>
</plist>
"""
        try content.write(to: infoPlistURL, atomically: true, encoding: .utf8)
    }

    // MARK: - File Collection

    /// Recursively collects all `.swift` files inside `directory`, returning paths relative to `base`.
    private func collectSwiftFiles(in directory: URL, relativeTo base: URL) -> [String] {
        guard let contents = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        ) else { return [] }

        var results: [String] = []
        let basePath = base.standardizedFileURL.path

        for item in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

            // Skip build artifacts and Xcode project/workspace directories.
            let name = item.lastPathComponent
            if isDir && (item.pathExtension == "xcodeproj" || item.pathExtension == "xcworkspace" || name == ".build") {
                continue
            }

            if isDir {
                results += collectSwiftFiles(in: item, relativeTo: base)
            } else if item.pathExtension == "swift" {
                let fullPath = item.standardizedFileURL.path
                let relative = fullPath.hasPrefix(basePath + "/")
                    ? String(fullPath.dropFirst(basePath.count + 1))
                    : item.lastPathComponent
                results.append(relative)
            }
        }
        return results
    }
}
