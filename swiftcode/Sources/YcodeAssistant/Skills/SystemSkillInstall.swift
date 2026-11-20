import Foundation
import Observation

/// A System Skill bundled with SwiftCode under `SC Skills/System Skills/<directory>/SKILL.md`.
public struct SystemSkill: Identifiable, Sendable, Hashable {
    public var id: String { directoryName }
    public let directoryName: String
    public let name: String
    public let description: String
    public let category: String
    public let tags: [String]
    public let content: String
    public let sourceURL: URL
}

/// Installs, lists and uninstalls SwiftCode System Skills.
///
/// Skills ship as package resources. Installing copies each skill directory into the
/// authoritative user skills library (`~/Library/Application Support/SwiftCode/Skills/System Skills`)
/// so `SkillIndex`, `SkillDiscoveryService`, the slash palette and every model can use them.
@MainActor
@Observable
public final class SystemSkillInstallManager {
    public static let shared = SystemSkillInstallManager()

    public nonisolated static let resourceDirectoryName = "System Skills"
    public nonisolated static let manifestFileName = ".system-skills-manifest.json"

    public private(set) var isWorking = false
    public private(set) var progress: Double = 0
    public private(set) var lastError: String?
    public private(set) var lastMessage: String?
    public private(set) var installedNames: Set<String> = []

    private let fileManager = FileManager.default
    private var cachedAvailable: [SystemSkill]?

    public init() {
        refreshInstalledState()
    }

    // MARK: - Locations

    /// Bundled source directory containing every System Skill.
    public nonisolated static func bundledSkillsDirectory() -> URL? {
        let candidates = [Bundle.module.resourceURL, Bundle.main.resourceURL].compactMap { $0 }
        for base in candidates {
            let url = base.appendingPathComponent("SC Skills", isDirectory: true).appendingPathComponent(resourceDirectoryName, isDirectory: true)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return nil
    }

    /// Destination inside the authoritative skills library.
    public var installDirectory: URL {
        SkillIndex.shared.authoritativeSkillsDirectory.appendingPathComponent(Self.resourceDirectoryName, isDirectory: true)
    }

    // MARK: - Catalog

    public func availableSkills() -> [SystemSkill] {
        if let cachedAvailable { return cachedAvailable }
        guard let root = Self.bundledSkillsDirectory(),
              let dirs = try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            lastError = "System Skills resources were not found in the app bundle."
            return []
        }
        let skills = dirs.compactMap { dir -> SystemSkill? in
            let file = dir.appendingPathComponent("SKILL.md")
            guard let text = try? String(contentsOf: file, encoding: .utf8) else { return nil }
            let meta = Self.frontMatter(text)
            return SystemSkill(
                directoryName: dir.lastPathComponent,
                name: meta["name"] ?? dir.lastPathComponent,
                description: meta["description"] ?? "",
                category: meta["category"] ?? "General",
                tags: (meta["tags"] ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "[]")).split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) },
                content: text,
                sourceURL: dir
            )
        }.sorted { ($0.category, $0.name) < ($1.category, $1.name) }
        cachedAvailable = skills
        return skills
    }

    public var categories: [String] { Array(Set(availableSkills().map(\.category))).sorted() }

    public func isInstalled(_ skill: SystemSkill) -> Bool { installedNames.contains(skill.directoryName) }
    public func installedCount() -> Int { installedNames.count }
    public var allInstalled: Bool { let a = availableSkills(); return !a.isEmpty && a.allSatisfy(isInstalled) }

    public func refreshInstalledState() {
        let dir = installDirectory
        let names = (try? fileManager.contentsOfDirectory(atPath: dir.path))?.filter {
            fileManager.fileExists(atPath: dir.appendingPathComponent($0).appendingPathComponent("SKILL.md").path)
        } ?? []
        installedNames = Set(names)
    }

    /// Parses simple `key: value` YAML front matter.
    public nonisolated static func frontMatter(_ text: String) -> [String: String] {
        guard text.hasPrefix("---") else { return [:] }
        let lines = text.components(separatedBy: .newlines).dropFirst()
        var out: [String: String] = [:]
        for line in lines {
            if line.trimmingCharacters(in: .whitespaces) == "---" { break }
            guard let colon = line.firstIndex(of: ":"), !line.hasPrefix(" ") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            out[key] = value
        }
        return out
    }

    // MARK: - Install / uninstall

    /// Installs (copies) every bundled System Skill, or only `skills` when provided.
    @discardableResult
    public func installAll(_ skills: [SystemSkill]? = nil, overwrite: Bool = true) async -> Int {
        let targets = skills ?? availableSkills()
        guard !targets.isEmpty else { lastError = "No System Skills available to install."; return 0 }
        isWorking = true; progress = 0; lastError = nil
        defer { isWorking = false }
        let dest = installDirectory
        var installed = 0
        var failures: [String] = []
        do {
            try fileManager.createDirectory(at: dest, withIntermediateDirectories: true)
        } catch {
            lastError = "Could not create \(dest.path): \(error.localizedDescription)"
            return 0
        }
        for (i, skill) in targets.enumerated() {
            let target = dest.appendingPathComponent(skill.directoryName, isDirectory: true)
            do {
                if fileManager.fileExists(atPath: target.path) {
                    guard overwrite else { installed += 1; continue }
                    try fileManager.removeItem(at: target)
                }
                try fileManager.copyItem(at: skill.sourceURL, to: target)
                UserDefaults.standard.set(true, forKey: "skill_enabled_\(skill.name)")
                installed += 1
            } catch {
                failures.append("\(skill.name): \(error.localizedDescription)")
            }
            progress = Double(i + 1) / Double(targets.count)
            if i % 20 == 0 { await Task.yield() }
        }
        writeManifest()
        refreshInstalledState()
        await SkillIndex.shared.rebuildIndex()
        if failures.isEmpty {
            lastMessage = "Installed \(installed) System Skills."
        } else {
            lastError = "Installed \(installed); \(failures.count) failed: " + failures.prefix(3).joined(separator: "; ")
        }
        return installed
    }

    public func install(_ skill: SystemSkill) async -> Bool {
        await installAll([skill]) == 1
    }

    /// Removes installed System Skills (all, or only `skills`). User-authored skills are never touched.
    @discardableResult
    public func uninstallAll(_ skills: [SystemSkill]? = nil) async -> Int {
        isWorking = true; lastError = nil
        defer { isWorking = false }
        let dest = installDirectory
        var removed = 0
        if let skills {
            for s in skills {
                let target = dest.appendingPathComponent(s.directoryName, isDirectory: true)
                guard fileManager.fileExists(atPath: target.path) else { continue }
                do { try fileManager.removeItem(at: target); removed += 1 } catch { lastError = error.localizedDescription }
            }
        } else if fileManager.fileExists(atPath: dest.path) {
            removed = installedNames.count
            do { try fileManager.removeItem(at: dest) } catch { lastError = error.localizedDescription; removed = 0 }
        }
        writeManifest()
        refreshInstalledState()
        await SkillIndex.shared.rebuildIndex()
        if lastError == nil { lastMessage = "Uninstalled \(removed) System Skills." }
        return removed
    }

    public func uninstall(_ skill: SystemSkill) async -> Bool {
        await uninstallAll([skill]) == 1
    }

    private func writeManifest() {
        let dest = installDirectory
        guard fileManager.fileExists(atPath: dest.path) else { return }
        let names = ((try? fileManager.contentsOfDirectory(atPath: dest.path)) ?? []).filter { !$0.hasPrefix(".") }.sorted()
        let manifest: [String: Any] = ["installedAt": ISO8601DateFormatter().string(from: Date()), "count": names.count, "skills": names]
        if let data = try? JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: dest.appendingPathComponent(Self.manifestFileName), options: .atomic)
        }
    }
}
