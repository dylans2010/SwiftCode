import Foundation
import Testing
@testable import SpacesEngine

@Suite struct StorageTests {
    @Test func continuousSnapshotsCaptureAndPrune() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        try SpacesTestSupport.write("v1", to: url.appendingPathComponent("f.txt"))
        try api.setContinuousSnapshotConfig(
            ContinuousSnapshotOps.ContinuousConfig(enabled: false, intervalMinutes: 0, maxSnapshots: 2))
        #expect(try api.captureWorkspaceSnapshotIfDue() == nil)

        try api.setContinuousSnapshotConfig(
            ContinuousSnapshotOps.ContinuousConfig(enabled: true, intervalMinutes: 0, maxSnapshots: 2))
        #expect(try api.captureWorkspaceSnapshotIfDue() != nil)
        #expect(try api.captureWorkspaceSnapshotIfDue() != nil)
        #expect(try api.captureWorkspaceSnapshotIfDue() != nil)
        let continuous = try ContinuousSnapshotOps(repo: api.repo).listContinuous()
        #expect(continuous.count == 2)
        #expect(continuous.allSatisfy { $0.kind == SnapshotOps.Kind.scheduled.rawValue })
        let stored = try api.continuousSnapshotConfig()
        #expect(stored.enabled)
        #expect(stored.maxSnapshots == 2)
    }

    @Test func snapshotBranchingAndCheckout() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f.txt": "original"], message: "base")
        let snapshot = try api.snapshot(message: "checkpoint")
        try SpacesTestSupport.write("changed", to: url.appendingPathComponent("f.txt"))
        let commitOID = try api.branchFromSnapshot(rev: snapshot.hex, name: "from-snapshot")
        #expect(try api.branches().contains { $0.name == "from-snapshot" })
        let branched = try api.repo.commitObject(commitOID)
        let snapshotPayload = try SnapshotOps(repo: api.repo).inspect(snapshot.hex)
        #expect(branched.tree == snapshotPayload.tree)

        try api.checkoutSnapshot(rev: snapshot.hex)
        #expect(try String(contentsOf: url.appendingPathComponent("f.txt"), encoding: .utf8) == "original")
    }

    @Test func snapshotDeduplicationReport() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["shared.txt": "shared-bytes", "a.txt": "a1"], message: "c1")
        _ = try api.snapshot(message: "first")
        _ = try SpacesTestSupport.commitFiles(api, ["a.txt": "a2"], message: "c2")
        _ = try api.snapshot(message: "second")
        let report = try api.snapshotDeduplicationReport()
        #expect(report.snapshotCount == 2)
        #expect(report.sharedBlobCount >= 1)
        #expect(report.bytesSaved > 0)
        #expect(report.naiveBytes > report.sharedBytes)
        #expect(report.perSnapshot.count == 2)
    }

    @Test func retentionPolicyPrunesOldestUnpinned() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "base")
        _ = try api.snapshot(message: "s1")
        _ = try api.snapshot(message: "s2")
        let newest = try api.snapshot(message: "s3")
        try api.setRetentionPolicy(RetentionPolicyOps.RetentionPolicy(
            maxAgeDays: nil, maxCount: 1, maxBytes: nil, pinned: [newest.hex]))
        let deleted = try api.applyRetentionPolicy()
        #expect(deleted.count == 2)
        #expect(!deleted.contains(newest))
        let remaining = try api.snapshots()
        #expect(remaining.count == 1)
        #expect(remaining[0].oid == newest)
        #expect(try api.retentionPolicy().maxCount == 1)
    }

    @Test func snapshotIntegrityDetectsCorruption() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f.txt": "precious"], message: "base")
        let snapshot = try api.snapshot(message: "guarded")
        let clean = try api.verifySnapshot(snapshot.hex)
        #expect(clean.valid)
        #expect(clean.checkedObjects > 0)
        #expect(try api.verifyAllSnapshots().allSatisfy { $0.valid })

        let payload = try SnapshotOps(repo: api.repo).inspect(snapshot.hex)
        let flat = try TreeBuilder.flattenTree(repo: api.repo, treeOID: payload.tree)
        guard let blobOID = flat.values.first?.oid else {
            Issue.record("snapshot tree has no blob")
            return
        }
        try Data("corrupt".utf8).write(to: api.repo.objects.url(for: blobOID))
        let damaged = try api.verifySnapshot(snapshot.hex)
        #expect(!damaged.valid)
        #expect(!damaged.issues.isEmpty)
        #expect(damaged.issues.contains { $0.contains(blobOID.hex) })
    }

    @Test func storageHeatmap() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f.txt": "data"], message: "base")
        _ = try api.snapshot(message: "snap")
        let heatmap = try api.storageHeatmap()
        #expect(heatmap.totalObjects > 0)
        #expect(heatmap.totalBytes > 0)
        #expect(heatmap.byType.contains { $0.label == ObjectType.blob.rawValue && $0.count > 0 })
        #expect(heatmap.reachableBytes > 0)
        #expect(heatmap.unreachableBytes >= 0)
        #expect(heatmap.totalBytes >= heatmap.reachableBytes)
        #expect(heatmap.sizeBands.map { $0.count }.reduce(0, +) == heatmap.totalObjects)
        #expect(heatmap.ageBands.map { $0.count }.reduce(0, +) == heatmap.totalObjects)
    }

    @Test func predictiveStorageGrowth() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f.txt": "one"], message: "c1")
        let first = try api.recordStorageSample()
        Thread.sleep(forTimeInterval: 1.1)
        _ = try SpacesTestSupport.commitFiles(api, ["g.txt": "two"], message: "c2")
        let second = try api.recordStorageSample()
        #expect(second.bytes >= first.bytes)
        let estimate = try api.storageGrowthEstimate()
        #expect(estimate.samples.count == 2)
        #expect(estimate.method.contains("projection"))
        #expect(!estimate.recommendation.isEmpty)
        #expect(estimate.projectedBytesAt30Days != nil)
        #expect((estimate.projectedBytesAt30Days ?? 0) >= second.bytes)
    }

    @Test func recoveryVaultRetainAndRestore() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        let file = url.appendingPathComponent("note.txt")
        try SpacesTestSupport.write("version one", to: file)
        let entries = try api.vaultRetain(paths: ["note.txt"], reason: "before edit")
        #expect(entries.count == 1)
        #expect(entries[0].path == "note.txt")
        #expect(entries[0].size == 11)
        try SpacesTestSupport.write("version two", to: file)
        let restored = try api.restoreFromVault(entry: entries[0].id)
        #expect(restored == "note.txt")
        #expect(try String(contentsOf: file, encoding: .utf8) == "version one")
        #expect(try api.vaultEntries().count == 1)
        #expect(throws: SpacesError.self) { try api.vaultRetain(paths: ["missing.txt"]) }
    }

    @Test func compactionProfiles() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "base")
        let profiles = try api.compactionProfiles()
        #expect(profiles.count == 3)
        #expect(profiles.map { $0.name }.sorted() ==
                ["read-optimized", "size-optimized", "write-optimized"])
        let before = try api.countObjects().total
        let result = try api.applyCompactionProfile(name: "size-optimized")
        #expect(result.profile == "size-optimized")
        #expect(result.objectsBefore == before)
        #expect(result.objectsAfter <= result.objectsBefore)
        #expect(result.bytesAfter <= result.bytesBefore)
        #expect(throws: SpacesError.self) { try api.applyCompactionProfile(name: "no-such-profile") }
    }

    @Test func incrementalBackupsVerifyAndRestore() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        let firstCommit = try SpacesTestSupport.commitFiles(
            api, ["a.txt": "alpha"], message: "c1")
        let bundleDir = try SpacesTestSupport.tempDir("backup-\(UUID().uuidString)")
        let firstPath = bundleDir.appendingPathComponent("first.spaces").path
        let first = try api.createBackup(to: firstPath)
        #expect(first.base == nil)
        #expect(!first.objects.isEmpty)
        let firstReport = try api.verifyBackup(url: firstPath)
        #expect(firstReport.objectCount == first.objects.count)

        _ = try SpacesTestSupport.commitFiles(api, ["b.txt": "beta"], message: "c2")
        let secondPath = bundleDir.appendingPathComponent("second.spaces").path
        let second = try api.createBackup(to: secondPath)
        #expect(second.base == first.id)
        #expect(second.objects.count < first.objects.count)
        #expect(second.objects.allSatisfy { !first.objects.contains($0) })
        let secondReport = try api.verifyBackup(url: secondPath)
        #expect(secondReport.objectCount == second.objects.count)
        #expect(try api.backups().count == 2)

        let (_, freshAPI, _) = try SpacesTestSupport.makeRepo()
        let restored = try freshAPI.restoreBackup(url: firstPath)
        #expect(restored.objectCount == first.objects.count)
        #expect(try freshAPI.countObjects().total > 0)
        _ = try freshAPI.repo.commitObject(firstCommit)
        _ = url
    }
}
