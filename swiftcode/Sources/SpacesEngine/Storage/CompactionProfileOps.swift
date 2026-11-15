import Foundation

public struct CompactionProfileOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct CompactionProfile: Codable, Sendable {
        public var name: String
        public var kind: String
        public var rebuildIndex: Bool
        public var pruneUnreachable: Bool
        public var pruneDays: Int

        public init(name: String, kind: String, rebuildIndex: Bool,
                    pruneUnreachable: Bool, pruneDays: Int) {
            self.name = name
            self.kind = kind
            self.rebuildIndex = rebuildIndex
            self.pruneUnreachable = pruneUnreachable
            self.pruneDays = pruneDays
        }
    }

    public struct CompactionResult: Sendable, Codable {
        public var profile: String
        public var objectsBefore: Int
        public var bytesBefore: Int64
        public var objectsAfter: Int
        public var bytesAfter: Int64
        public var pruned: Int
    }

    private static func defaultProfiles() -> [CompactionProfile] {
        [
            CompactionProfile(name: "read-optimized", kind: "read-optimized",
                              rebuildIndex: true, pruneUnreachable: false, pruneDays: 0),
            CompactionProfile(name: "size-optimized", kind: "size-optimized",
                              rebuildIndex: true, pruneUnreachable: true, pruneDays: 0),
            CompactionProfile(name: "write-optimized", kind: "write-optimized",
                              rebuildIndex: false, pruneUnreachable: true, pruneDays: 30),
        ]
    }

    public func compactionProfiles() throws -> [CompactionProfile] {
        let url = try StorageFileIO.directory(repo: repo).appendingPathComponent("compaction.json")
        if let data = try? Data(contentsOf: url),
           let profiles = try? JSONDecoder().decode([CompactionProfile].self, from: data),
           !profiles.isEmpty {
            return profiles
        }
        let defaults = Self.defaultProfiles()
        try StorageFileIO.save(repo: repo, name: "compaction.json", value: defaults)
        return defaults
    }

    @discardableResult
    public func createCompactionProfile(_ profile: CompactionProfile) throws -> CompactionProfile {
        let trimmedName = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw SpacesError.invalidArgument("compaction profile name must not be empty")
        }
        guard !profile.kind.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SpacesError.invalidArgument("compaction profile kind must not be empty")
        }
        guard profile.pruneDays >= 0 else {
            throw SpacesError.invalidArgument("compaction profile pruneDays must not be negative")
        }
        var stored = profile
        stored.name = trimmedName
        return try repo.withLock {
            var profiles = try compactionProfiles()
            guard !profiles.contains(where: { $0.name == trimmedName }) else {
                throw SpacesError.invalidArgument("compaction profile already exists: \(trimmedName)")
            }
            profiles.append(stored)
            try StorageFileIO.save(repo: repo, name: "compaction.json", value: profiles)
            return stored
        }
    }

    @discardableResult
    public func updateCompactionProfile(name: String, profile: CompactionProfile) throws -> CompactionProfile {
        let trimmedName = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw SpacesError.invalidArgument("compaction profile name must not be empty")
        }
        guard !profile.kind.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SpacesError.invalidArgument("compaction profile kind must not be empty")
        }
        guard profile.pruneDays >= 0 else {
            throw SpacesError.invalidArgument("compaction profile pruneDays must not be negative")
        }
        var stored = profile
        stored.name = trimmedName
        return try repo.withLock {
            var profiles = try compactionProfiles()
            guard let index = profiles.firstIndex(where: { $0.name == name }) else {
                throw SpacesError.invalidArgument("unknown compaction profile \(name)")
            }
            if trimmedName != name, profiles.contains(where: { $0.name == trimmedName }) {
                throw SpacesError.invalidArgument("compaction profile already exists: \(trimmedName)")
            }
            profiles[index] = stored
            try StorageFileIO.save(repo: repo, name: "compaction.json", value: profiles)
            return stored
        }
    }

    public func deleteCompactionProfile(name: String) throws {
        try repo.withLock {
            var profiles = try compactionProfiles()
            guard let index = profiles.firstIndex(where: { $0.name == name }) else {
                throw SpacesError.invalidArgument("unknown compaction profile \(name)")
            }
            profiles.remove(at: index)
            try StorageFileIO.save(repo: repo, name: "compaction.json", value: profiles)
        }
    }

    @discardableResult
    public func applyCompactionProfile(name: String) throws -> CompactionResult {
        guard let profile = try compactionProfiles().first(where: { $0.name == name }) else {
            throw SpacesError.invalidArgument("unknown compaction profile \(name)")
        }
        let maintenance = MaintenanceOps(repo: repo)
        let before = try maintenance.countObjects()
        let beforeBytes = try maintenance.storage().objects
        var pruned = 0
        if profile.rebuildIndex { _ = try maintenance.rebuildIndex() }
        if profile.pruneUnreachable {
            pruned = try maintenance.gc(pruneDays: profile.pruneDays).pruned
        }
        let after = try maintenance.countObjects()
        let afterBytes = try maintenance.storage().objects
        return CompactionResult(profile: profile.name, objectsBefore: before.total,
                                bytesBefore: beforeBytes, objectsAfter: after.total,
                                bytesAfter: afterBytes, pruned: pruned)
    }
}
