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
    func prepareXcodeFiles(for project: Project) {
        let projectDir = project.directoryURL
        if hasXcodeProjectFiles(in: projectDir) {
            // Existing files found — load and use them without regenerating.
            return
        }
        generateXcodeProject(for: project)
    }

    /// Call this when a ZIP-imported project directory has been set up.
    /// Applies the same rules: skip generation if `.xcodeproj`/`.xcworkspace` already exist.
    /// - Parameters:
    ///   - projectDir: The root directory of the imported project.
    ///   - projectName: The name used for the generated project files.
    func prepareXcodeFilesForImport(projectDir: URL, projectName: String) {
        if hasXcodeProjectFiles(in: projectDir) {
            return
        }
        generateXcodeProjectFiles(in: projectDir, projectName: projectName)
    }

    /// Call this when a user adds, removes, or renames files inside the project.
    /// Regenerates the source-file list inside the `.xcodeproj` so the target stays valid.
    /// - Parameter project: The SwiftCode project whose file tree changed.
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

        return contents.contains {
            $0.pathExtension == "xcodeproj" || $0.pathExtension == "xcworkspace"
        }
    }

    // MARK: - Generation

    /// Generates both `.xcodeproj` and `.xcworkspace` for a SwiftCode project.
    private func generateXcodeProject(for project: Project) {
        generateXcodeProjectFiles(in: project.directoryURL, projectName: project.name)
    }

    /// Generates the full Xcode project structure inside `projectDir`.
    private func generateXcodeProjectFiles(in projectDir: URL, projectName: String) {
        do {
            try ensureSubdirectories(in: projectDir)
            let xcodeProjectDir = projectDir.appendingPathComponent("\(projectName).xcodeproj")
            try fm.createDirectory(at: xcodeProjectDir, withIntermediateDirectories: true)
            try writeProjectPBX(in: xcodeProjectDir, projectDir: projectDir, projectName: projectName)
            try writeXcscheme(in: xcodeProjectDir, projectName: projectName)
            try writeXcworkspace(in: projectDir, projectName: projectName)
        } catch {
            // Generation is best-effort; failures are non-fatal.
        }
    }

    // MARK: - Subdirectory Scaffolding

    /// Ensures the expected source/asset subdirectories exist without overwriting any files.
    private func ensureSubdirectories(in projectDir: URL) throws {
        let subdirectories = ["Sources", "Sources/Views", "Sources/Features", "Assets"]
        for sub in subdirectories {
            let dir = projectDir.appendingPathComponent(sub)
            if !fm.fileExists(atPath: dir.path) {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
    }

    // MARK: - project.pbxproj

    /// Writes a minimal but valid `project.pbxproj` that includes all Swift source files found
    /// in the project directory under the main application target.
    private func writeProjectPBX(in xcodeProjectDir: URL, projectDir: URL, projectName: String) throws {
        let pbxURL = xcodeProjectDir.appendingPathComponent("project.pbxproj")

        // Preserve existing file if present — only overwrite when genuinely missing.
        guard !fm.fileExists(atPath: pbxURL.path) else { return }

        let swiftFiles = collectSwiftFiles(in: projectDir, relativeTo: projectDir)
        let pbxContent = buildProjectPBX(projectName: projectName, swiftFiles: swiftFiles)
        try pbxContent.write(to: pbxURL, atomically: true, encoding: .utf8)
    }

    /// Regenerates only the `project.pbxproj` for a project that already has an `.xcodeproj`.
    /// Writes a new file to reflect current source files.
    private func regenerateProjectPBX(in xcodeProjectDir: URL, projectDir: URL, projectName: String) {
        let pbxURL = xcodeProjectDir.appendingPathComponent("project.pbxproj")
        let swiftFiles = collectSwiftFiles(in: projectDir, relativeTo: projectDir)
        let pbxContent = buildProjectPBX(projectName: projectName, swiftFiles: swiftFiles)
        try? pbxContent.write(to: pbxURL, atomically: true, encoding: .utf8)
    }

    /// Builds a minimal `project.pbxproj` string referencing the given Swift source files.
    private func buildProjectPBX(projectName: String, swiftFiles: [String]) -> String {
        // Generate stable-ish UUIDs by hashing file paths so repeated regeneration
        // keeps the same references and avoids unnecessary diffs.
        let projectUUID    = deterministicUUID("project:\(projectName)")
        let mainGroupUUID  = deterministicUUID("group:\(projectName)")
        let sourcesGroupUUID = deterministicUUID("group:sources:\(projectName)")
        let productsGroupUUID = deterministicUUID("group:products:\(projectName)")
        let targetUUID     = deterministicUUID("target:\(projectName)")
        let projectConfigListUUID = deterministicUUID("configlist:project:\(projectName)")
        let targetConfigListUUID  = deterministicUUID("configlist:target:\(projectName)")
        let debugConfigUUID = deterministicUUID("debug:\(projectName)")
        let releaseConfigUUID = deterministicUUID("release:\(projectName)")
        let productFileUUID = deterministicUUID("product:\(projectName)")
        let sourcesBuildPhaseUUID = deterministicUUID("buildphase:sources:\(projectName)")
        let frameworksBuildPhaseUUID = deterministicUUID("buildphase:frameworks:\(projectName)")

        // Build file references and build file entries for each Swift source.
        var fileRefSection = ""
        var buildFileSection = ""
        var sourcesBuildFiles: [String] = []

        for filePath in swiftFiles {
            let fileRefUUID = deterministicUUID("fileref:\(filePath)")
            let buildFileUUID = deterministicUUID("buildfile:\(filePath)")
            let fileName = URL(fileURLWithPath: filePath).lastPathComponent
            fileRefSection += """
\t\t\(fileRefUUID) /* \(fileName) */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \(fileName); sourceTree = "<group>"; };
"""
            buildFileSection += """
\t\t\(buildFileUUID) /* \(fileName) in Sources */ = {isa = PBXBuildFile; fileRef = \(fileRefUUID) /* \(fileName) */; };
"""
            sourcesBuildFiles.append("\(buildFileUUID) /* \(fileName) in Sources */,")
        }

        let sourcesPhaseFiles = sourcesBuildFiles.map { "\t\t\t\t\($0)" }.joined(separator: "\n")

        return """
// !$*UTF8*$!
{
\tarchiveVersion = 1;
\tclasses = {
\t};
\tobjectVersion = 56;
\tobjects = {

/* Begin PBXBuildFile section */
\(buildFileSection)
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
\t\t\(productFileUUID) /* \(projectName).app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = \(projectName).app; sourceTree = BUILT_PRODUCTS_DIR; };
\(fileRefSection)
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
\t\t\(frameworksBuildPhaseUUID) /* Frameworks */ = {
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
\t\t\(mainGroupUUID) = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t\(sourcesGroupUUID) /* Sources */,
\t\t\t\t\(productsGroupUUID) /* Products */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t};
\t\t\(sourcesGroupUUID) /* Sources */ = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\(swiftFiles.map { "\t\t\t\t\(deterministicUUID("fileref:\($0)")) /* \(URL(fileURLWithPath: $0).lastPathComponent) */," }.joined(separator: "\n"))
\t\t\t);
\t\t\tname = Sources;
\t\t\tsourceTree = "<group>";
\t\t};
\t\t\(productsGroupUUID) /* Products */ = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t\(productFileUUID) /* \(projectName).app */,
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t\(targetUUID) /* \(projectName) */ = {
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = \(targetConfigListUUID) /* Build configuration list for PBXNativeTarget "\(projectName)" */;
\t\t\tbuildPhases = (
\t\t\t\t\(sourcesBuildPhaseUUID) /* Sources */,
\t\t\t\t\(frameworksBuildPhaseUUID) /* Frameworks */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = \(projectName);
\t\t\tproductName = \(projectName);
\t\t\tproductReference = \(productFileUUID) /* \(projectName).app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t\(projectUUID) /* Project object */ = {
\t\t\tisa = PBXProject;
\t\t\tbuildConfigurationList = \(projectConfigListUUID) /* Build configuration list for PBXProject "\(projectName)" */;
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = \(mainGroupUUID);
\t\t\tproductRefGroup = \(productsGroupUUID) /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t\(targetUUID) /* \(projectName) */,
\t\t\t);
\t\t};
/* End PBXProject section */

/* Begin PBXSourcesBuildPhase section */
\t\t\(sourcesBuildPhaseUUID) /* Sources */ = {
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\(sourcesPhaseFiles)
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
\t\t\(debugConfigUUID) /* Debug */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "com.swiftcode.\(projectName.replacingOccurrences(of: " ", with: "").lowercased())";
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_VERSION = 5.9;
\t\t\t};
\t\t\tname = Debug;
\t\t};
\t\t\(releaseConfigUUID) /* Release */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "com.swiftcode.\(projectName.replacingOccurrences(of: " ", with: "").lowercased())";
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_VERSION = 5.9;
\t\t\t};
\t\t\tname = Release;
\t\t};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t\(projectConfigListUUID) /* Build configuration list for PBXProject "\(projectName)" */ = {
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t\(debugConfigUUID) /* Debug */,
\t\t\t\t\(releaseConfigUUID) /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t};
\t\t\(targetConfigListUUID) /* Build configuration list for PBXNativeTarget "\(projectName)" */ = {
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t\(debugConfigUUID) /* Debug */,
\t\t\t\t\(releaseConfigUUID) /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t};
/* End XCConfigurationList section */
\t};
\trootObject = \(projectUUID) /* Project object */;
}
"""
    }

    // MARK: - .xcscheme

    private func writeXcscheme(in xcodeProjectDir: URL, projectName: String) throws {
        let schemesDir = xcodeProjectDir
            .appendingPathComponent("xcshareddata")
            .appendingPathComponent("xcschemes")
        try fm.createDirectory(at: schemesDir, withIntermediateDirectories: true)

        let schemeURL = schemesDir.appendingPathComponent("\(projectName).xcscheme")
        guard !fm.fileExists(atPath: schemeURL.path) else { return }

        let targetUUID = deterministicUUID("target:\(projectName)")
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

    private func writeXcworkspace(in projectDir: URL, projectName: String) throws {
        let workspaceDir = projectDir.appendingPathComponent("\(projectName).xcworkspace")
        try fm.createDirectory(at: workspaceDir, withIntermediateDirectories: true)

        let contentsURL = workspaceDir.appendingPathComponent("contents.xcworkspacedata")
        guard !fm.fileExists(atPath: contentsURL.path) else { return }

        let contents = """
<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "group:\(projectName).xcodeproj">
   </FileRef>
</Workspace>
"""
        try contents.write(to: contentsURL, atomically: true, encoding: .utf8)
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
            // Skip Xcode project/workspace directories to avoid infinite recursion.
            if isDir && (item.pathExtension == "xcodeproj" || item.pathExtension == "xcworkspace") {
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

    // MARK: - Deterministic UUID Generation

    /// Produces a deterministic 24-character hex string resembling a PBX UUID by hashing the key.
    private func deterministicUUID(_ key: String) -> String {
        var hash: UInt64 = 14695981039346656037
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1099511628211
        }
        let hex = String(format: "%016llX", hash)
        // Pad to 24 characters as PBX UUIDs are 24 hex chars.
        let padded = (hex + hex).prefix(24)
        return String(padded).uppercased()
    }
}
