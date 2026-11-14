import Foundation
import YcodeProject

/// Extensions that mark a file package as a project container. Only these
/// are stripped for display; a folder that merely contains a dot keeps its
/// full last path component.
private let recentProjectContainerExtensions: Set<String> = ["xcodeproj", "xcworkspace", "swiftpm", "scproj"]

@MainActor
public final class RecentProjects {
    public static let didChange = Notification.Name("SwiftCodeRecentProjectsDidChange")
    public static var shared = RecentProjects(defaults: IDEProcess.isTestProcess
        ? UserDefaults(suiteName: NSTemporaryDirectory() + "swiftcode-recent-projects-\(ProcessInfo.processInfo.processIdentifier)") ?? .standard
        : .standard)

    public static let defaultsKey = "SwiftCode.recentProjects"
    public static let limit = 10

    let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public var urls: [URL] {
        let stored = defaults.stringArray(forKey: Self.defaultsKey) ?? []
        let present = stored.filter { FileManager.default.fileExists(atPath: $0) }
        if present.count != stored.count { defaults.set(present, forKey: Self.defaultsKey) }
        return present.map { Self.containerURL(URL(fileURLWithPath: $0)) }
    }

    public func note(_ url: URL) {
        let path = Self.containerURL(url).path
        var list = defaults.stringArray(forKey: Self.defaultsKey) ?? []
        list.removeAll { $0 == path }
        list.insert(path, at: 0)
        defaults.set(Array(list.prefix(Self.limit)), forKey: Self.defaultsKey)
        persist()
        NotificationCenter.default.post(name: Self.didChange, object: self)
        let rootURL = Self.containerURL(url)
        let ext = rootURL.pathExtension.lowercased()
        let name = Self.containerExtensions.contains(ext)
            ? rootURL.deletingPathExtension().lastPathComponent
            : rootURL.lastPathComponent
        let kind: ProjectKind
        if ext == "xcodeproj" {
            kind = .xcodeProject
        } else if FileManager.default.fileExists(
            atPath: rootURL.appendingPathComponent("Package.swift").path) {
            kind = .swiftPackage
        } else {
            kind = .folder
        }
        Task { try? await ProjectRegistryStore.shared.note(rootURL: rootURL, name: name, kind: kind) }
    }

    public func remove(_ url: URL) {
        let path = Self.containerURL(url).path
        var list = defaults.stringArray(forKey: Self.defaultsKey) ?? []
        list.removeAll { $0 == path }
        defaults.set(list, forKey: Self.defaultsKey)
        persist()
        NotificationCenter.default.post(name: Self.didChange, object: self)
    }

    public func clear() {
        defaults.removeObject(forKey: Self.defaultsKey)
        persist()
        NotificationCenter.default.post(name: Self.didChange, object: self)
    }

    private func persist() {
        #if os(Linux)
        defaults.synchronize()
        #endif
    }

    /// The URL of the project container a path belongs to. Recent entries can
    /// point at a package's `Package.swift` or at files inside an
    /// `.xcodeproj`/`.xcworkspace` bundle; this unwraps them to the container
    /// itself so names and icons describe the project, not an inner file.
    public nonisolated static func containerURL(_ url: URL) -> URL {
        var u = url.standardizedFileURL
        while u.lastPathComponent == "Package.swift" {
            u = u.deletingLastPathComponent()
        }
        // Only absolute file URLs have a filesystem root to walk up to. For a
        // relative URL, deletingLastPathComponent keeps producing "./", "../",
        // "../../", … and the loop below would never terminate.
        guard u.isFileURL, u.path.hasPrefix("/") else { return u }
        // Truncate at the outermost project container bundle so that any file
        // inside a .xcodeproj/.xcworkspace (project.pbxproj, xcschemes,
        // xcuserdata, …) resolves to the bundle itself.
        var container = u
        var cursor = u
        // NSURL-bridged file URLs (what AppKit vends) do not converge at the
        // filesystem root: deletingLastPathComponent keeps producing
        // "file:///../../.." forever. Stop once the path reaches "/".
        while cursor.path != "/" {
            let parent = cursor.deletingLastPathComponent()
            if parent == cursor || !parent.path.hasPrefix("/") { break }
            if recentProjectContainerExtensions.contains(parent.pathExtension.lowercased()) { container = parent }
            cursor = parent
        }
        return container
    }

    static let containerExtensions: Set<String> = recentProjectContainerExtensions

    public static func menuTitles(_ urls: [URL]) -> [String] {
        let names = urls.map { displayName($0) }
        let counts = Dictionary(grouping: names, by: { $0 }).mapValues(\.count)
        return zip(urls, names).map { url, name in
            counts[name, default: 0] > 1 ? "\(name) \u{2014}  \(url.deletingLastPathComponent().lastPathComponent)" : name
        }
    }

    public static func displayName(_ url: URL) -> String {
        let u = containerURL(url)
        return containerExtensions.contains(u.pathExtension.lowercased()) ? u.deletingPathExtension().lastPathComponent : u.lastPathComponent
    }

    public static func folderText(_ url: URL) -> String {
        let folder = containerURL(url).deletingLastPathComponent().standardizedFileURL
        let parts = folder.pathComponents
        if parts.count >= 3, parts[1] == "Volumes" {
            return parts[2...].joined(separator: "/")
        }
        let values = try? folder.resourceValues(forKeys: [.volumeNameKey])
        guard let volume = values?.volumeName else { return folder.path }
        return ([volume] + parts.dropFirst()).joined(separator: "/")
    }

    /// The app version of the project at `url`, read live from the
    /// `.xcodeproj` build settings (`MARKETING_VERSION`, falling back to
    /// `CURRENT_PROJECT_VERSION`) at call time. App targets are preferred over
    /// other targets, and the project-level configuration is the last resort.
    /// Either field is nil when the project has no readable `.xcodeproj`
    /// settings (plain folders, SwiftPM packages, unreadable files).
    public nonisolated static func projectVersionInfo(at url: URL) -> (marketing: String?, build: String?) {
        let root = containerURL(url)
        let project: URL
        if root.pathExtension.lowercased() == "xcodeproj" {
            project = root
        } else {
            var candidates = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
            if root.pathExtension.lowercased() == "xcworkspace", candidates.isEmpty {
                candidates = (try? FileManager.default.contentsOfDirectory(at: root.deletingLastPathComponent(), includingPropertiesForKeys: nil)) ?? []
            }
            let bundles = candidates.filter { $0.pathExtension == "xcodeproj" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            guard let found = bundles.first(where: {
                $0.deletingPathExtension().lastPathComponent == root.lastPathComponent
            }) ?? bundles.first else { return (nil, nil) }
            project = found
        }
        guard let proj = try? PBXProj(contentsOf: project) else { return (nil, nil) }

        func settings(of object: PBXObject) -> [String: String] {
            guard let listID = object.string("buildConfigurationList"),
                  let list = proj.objects.values.first(where: { $0.id == listID && $0.isa == "XCConfigurationList" })
            else { return [:] }
            var result: [String: String] = [:]
            for configID in list.references("buildConfigurations") {
                guard let config = proj.objects[configID], config.isa == "XCBuildConfiguration",
                      let buildSettings = config.attributes["buildSettings"]?.dictionary else { continue }
                for (key, value) in buildSettings where result[key] == nil {
                    if let string = value.string, !string.isEmpty { result[key] = string }
                }
            }
            return result
        }

        let natives = proj.objects(isa: "PBXNativeTarget")
        let apps = natives.filter { $0.string("productType") == "com.apple.product-type.application" }
        let ordered = apps + natives.filter { !apps.contains($0) }
        var marketing: String?
        var build: String?
        for target in ordered {
            let s = settings(of: target)
            if marketing == nil {
                marketing = s["MARKETING_VERSION"] ?? s["CURRENT_PROJECT_VERSION"]
            }
            if build == nil { build = s["CURRENT_PROJECT_VERSION"] }
            if marketing != nil && build != nil { break }
        }
        if marketing == nil || build == nil, let projectObject = proj.project {
            let s = settings(of: projectObject)
            if marketing == nil { marketing = s["MARKETING_VERSION"] ?? s["CURRENT_PROJECT_VERSION"] }
            if build == nil { build = s["CURRENT_PROJECT_VERSION"] }
        }
        return (marketing, build)
    }
}
