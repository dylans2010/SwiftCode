import Foundation

public struct PatchCollectionOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public static let supportedSubsetDescription = "Supported patch subset: unified diffs emitted by the Spaces diff engine for single-file create, modify, and delete hunks with context lines. Binary files and mode-only changes carry no hunks and are skipped. A hunk whose context lines do not match the worktree throws invalidArgument and applies nothing for that file."

    public struct StoredPatch: Codable, Sendable, Equatable {
        public var commit: String
        public var patchText: String

        public init(commit: String, patchText: String) {
            self.commit = commit
            self.patchText = patchText
        }
    }

    public struct PatchCollection: Codable, Sendable, Equatable {
        public var name: String
        public var patches: [StoredPatch]

        public init(name: String, patches: [StoredPatch]) {
            self.name = name
            self.patches = patches
        }
    }

    public func createPatchCollection(name: String, from: String, to: String) throws -> PatchCollection {
        guard !name.isEmpty, !name.contains("/"), name != "..", name != "." else {
            throw SpacesError.invalidArgument("invalid patch collection name: " + name)
        }
        let fromOID = try repo.resolveRevision(from)
        let toOID = try repo.resolveRevision(to)
        let walked = try HistoryOps(repo: repo).walk(start: toOID, firstParentOnly: true, limit: 10000)
        guard walked.contains(where: { $0.oid == fromOID }) else {
            throw SpacesError.invalidArgument("from revision is not an ancestor of to revision")
        }
        var commits: [HistoryOps.CommitInfo] = []
        for commit in walked {
            if commit.oid == fromOID { break }
            commits.append(commit)
        }
        commits.reverse()
        var stored: [StoredPatch] = []
        for commit in commits {
            let patch: String
            if let parent = commit.parents.first {
                let diffs = try DiffOps(repo: repo).diffTrees(try repo.commitObject(parent).tree, try repo.commitObject(commit.oid).tree)
                patch = DiffOps.renderPatch(diffs)
            } else {
                let emptyTree = try TreeBuilder.emptyTree(objects: repo.objects)
                let diffs = try DiffOps(repo: repo).diffTrees(emptyTree, try repo.commitObject(commit.oid).tree)
                patch = DiffOps.renderPatch(diffs)
            }
            stored.append(StoredPatch(commit: commit.oid.hex, patchText: patch))
        }
        let collection = PatchCollection(name: name, patches: stored)
        try repo.withLock {
            try ToolingStorage.atomicWriteJSON(repo: repo, relativePath: "tooling/patches/" + name + ".json", value: collection)
        }
        return collection
    }

    public func patchCollections() throws -> [PatchCollection] {
        let dir = try ToolingStorage.toolingDir(repo: repo).appendingPathComponent("patches")
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { return [] }
        var collections: [PatchCollection] = []
        for file in names.filter({ $0.hasSuffix(".json") }).sorted() {
            let name = String(file.dropLast(".json".count))
            if let collection = try? patchCollection(named: name) {
                collections.append(collection)
            }
        }
        return collections
    }

    public func patchCollection(named name: String) throws -> PatchCollection {
        guard !name.isEmpty, !name.contains("/"), name != "..", name != "." else {
            throw SpacesError.invalidArgument("invalid patch collection name: " + name)
        }
        guard let collection: PatchCollection = try ToolingStorage.readJSON(repo: repo, relativePath: "tooling/patches/" + name + ".json") else {
            throw SpacesError.invalidArgument("no patch collection named " + name)
        }
        return collection
    }

    public func applyPatchCollection(name: String) throws -> [String] {
        let collection = try patchCollection(named: name)
        return try repo.withLock {
            var applied: [String] = []
            for stored in collection.patches {
                let commitOID = try ObjectID(validating: stored.commit)
                let commit = try repo.commitObject(commitOID)
                let diffs: [DiffOps.FileDiff]
                if let parent = commit.parents.first {
                    diffs = try DiffOps(repo: repo).diffTrees(try repo.commitObject(parent).tree, commit.tree)
                } else {
                    let emptyTree = try TreeBuilder.emptyTree(objects: repo.objects)
                    diffs = try DiffOps(repo: repo).diffTrees(emptyTree, commit.tree)
                }
                var statusByPath: [String: DiffOps.FileDiff.StatusKind] = [:]
                for diff in diffs {
                    statusByPath[diff.newPath] = diff.status
                    statusByPath[diff.oldPath] = diff.status
                }
                let filePaths = try applyPatchText(stored.patchText, statusByPath: statusByPath)
                applied.append(contentsOf: filePaths)
            }
            return Array(Set(applied)).sorted()
        }
    }

    private func applyPatchText(_ patchText: String, statusByPath: [String: DiffOps.FileDiff.StatusKind]) throws -> [String] {
        var applied: [String] = []
        let lines = patchText.components(separatedBy: "\n")
        var sectionStart = -1
        var sections: [[String]] = []
        for (index, line) in lines.enumerated() {
            if line.hasPrefix("--- ") {
                if sectionStart >= 0 {
                    sections.append(Array(lines[sectionStart..<index]))
                }
                sectionStart = index
            }
        }
        if sectionStart >= 0 {
            sections.append(Array(lines[sectionStart..<lines.count]))
        }
        for section in sections {
            guard let paths = try applyFileSection(section, statusByPath: statusByPath) else { continue }
            applied.append(paths)
        }
        return applied
    }

    private func applyFileSection(_ section: [String], statusByPath: [String: DiffOps.FileDiff.StatusKind]) throws -> String? {
        var oldPath: String? = nil
        var newPath: String? = nil
        var hasHunks = false
        for line in section {
            if line.hasPrefix("--- ") {
                let target = String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                if target != "/dev/null" {
                    oldPath = stripDiffPrefix(target)
                }
            }
            if line.hasPrefix("+++ ") {
                let target = String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                if target != "/dev/null" {
                    newPath = stripDiffPrefix(target)
                }
            }
            if line.hasPrefix("@@") { hasHunks = true }
        }
        if section.contains(where: { $0 == "Binary files differ" }) || !hasHunks {
            return nil
        }
        let targetPath = newPath ?? oldPath
        guard let path = targetPath else { return nil }
        let status = statusByPath[path]
        let sectionText = section.joined(separator: "\n")
        if status == .deleted {
            let url = try repo.worktreeURL(forRelativePath: path)
            guard let current = try? String(contentsOf: url, encoding: .utf8) else {
                throw SpacesError.invalidArgument("patch does not apply: missing file " + path)
            }
            guard let result = DiffOps.applyPatch(to: current, patch: sectionText), result.isEmpty else {
                throw SpacesError.invalidArgument("patch does not apply to " + path)
            }
            try FileManager.default.removeItem(at: url)
            return path
        }
        if status == .added {
            guard let result = DiffOps.applyPatch(to: "", patch: sectionText) else {
                throw SpacesError.invalidArgument("patch does not apply to new file " + path)
            }
            let url = try repo.worktreeURL(forRelativePath: path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(result.utf8).write(to: url, options: .atomic)
            return path
        }
        if let old = oldPath, let new = newPath, old != new {
            let oldURL = try repo.worktreeURL(forRelativePath: old)
            let current = (try? String(contentsOf: oldURL, encoding: .utf8)) ?? ""
            guard let result = DiffOps.applyPatch(to: current, patch: sectionText) else {
                throw SpacesError.invalidArgument("patch does not apply to " + old)
            }
            let newURL = try repo.worktreeURL(forRelativePath: new)
            try FileManager.default.createDirectory(at: newURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(result.utf8).write(to: newURL, options: .atomic)
            try FileManager.default.removeItem(at: oldURL)
            return new
        }
        let url = try repo.worktreeURL(forRelativePath: path)
        guard let current = try? String(contentsOf: url, encoding: .utf8) else {
            throw SpacesError.invalidArgument("patch does not apply: missing file " + path)
        }
        guard let result = DiffOps.applyPatch(to: current, patch: sectionText) else {
            throw SpacesError.invalidArgument("patch does not apply to " + path)
        }
        try Data(result.utf8).write(to: url, options: .atomic)
        return path
    }

    private func stripDiffPrefix(_ path: String) -> String {
        if path.hasPrefix("a/") || path.hasPrefix("b/") {
            return String(path.dropFirst(2))
        }
        return path
    }
}
