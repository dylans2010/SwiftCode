import Foundation

extension SpacesAPI {
    public func continuousSnapshotConfig() throws -> ContinuousSnapshotOps.ContinuousConfig {
        try ContinuousSnapshotOps(repo: repo).config()
    }

    public func setContinuousSnapshotConfig(_ config: ContinuousSnapshotOps.ContinuousConfig) throws {
        try ContinuousSnapshotOps(repo: repo).setConfig(config)
    }

    @discardableResult
    public func captureWorkspaceSnapshotIfDue() throws -> ObjectID? {
        try ContinuousSnapshotOps(repo: repo).captureIfDue()
    }

    @discardableResult
    public func branchFromSnapshot(rev: String, name: String) throws -> ObjectID {
        try SnapshotBranchingOps(repo: repo).branchFromSnapshot(rev: rev, name: name)
    }

    public func checkoutSnapshot(rev: String) throws {
        try SnapshotBranchingOps(repo: repo).checkoutSnapshot(rev: rev)
    }

    public func snapshotDeduplicationReport() throws -> SnapshotDedupOps.DeduplicationReport {
        try SnapshotDedupOps(repo: repo).deduplicationReport()
    }

    public func retentionPolicy() throws -> RetentionPolicyOps.RetentionPolicy {
        try RetentionPolicyOps(repo: repo).policy()
    }

    public func setRetentionPolicy(_ policy: RetentionPolicyOps.RetentionPolicy) throws {
        try RetentionPolicyOps(repo: repo).setPolicy(policy)
    }

    @discardableResult
    public func applyRetentionPolicy() throws -> [ObjectID] {
        try RetentionPolicyOps(repo: repo).applyRetention()
    }

    public func verifySnapshot(_ rev: String) throws -> SnapshotIntegrityOps.SnapshotVerification {
        try SnapshotIntegrityOps(repo: repo).verifySnapshot(rev: rev)
    }

    public func verifyAllSnapshots() throws -> [SnapshotIntegrityOps.SnapshotVerification] {
        try SnapshotIntegrityOps(repo: repo).verifyAllSnapshots()
    }

    public func storageHeatmap() throws -> StorageHeatmapOps.StorageHeatmap {
        try StorageHeatmapOps(repo: repo).heatmap()
    }

    @discardableResult
    public func recordStorageSample() throws -> PredictiveStorageOps.StorageSample {
        try PredictiveStorageOps(repo: repo).recordStorageSample()
    }

    public func storageGrowthEstimate() throws -> PredictiveStorageOps.GrowthEstimate {
        try PredictiveStorageOps(repo: repo).growthEstimate()
    }

    @discardableResult
    public func vaultRetain(paths: [String], reason: String = "retained") throws -> [RecoveryVaultOps.VaultEntry] {
        try RecoveryVaultOps(repo: repo).vaultRetain(paths: paths, reason: reason)
    }

    public func vaultEntries() throws -> [RecoveryVaultOps.VaultEntry] {
        try RecoveryVaultOps(repo: repo).vaultEntries()
    }

    @discardableResult
    public func restoreFromVault(entry id: String, path: String? = nil) throws -> String {
        try RecoveryVaultOps(repo: repo).restoreFromVault(entry: id, path: path)
    }

    public func compactionProfiles() throws -> [CompactionProfileOps.CompactionProfile] {
        try CompactionProfileOps(repo: repo).compactionProfiles()
    }

    @discardableResult
    public func applyCompactionProfile(name: String) throws -> CompactionProfileOps.CompactionResult {
        try CompactionProfileOps(repo: repo).applyCompactionProfile(name: name)
    }

    @discardableResult
    public func createBackup(to path: String) throws -> IncrementalBackupOps.BackupManifest {
        try IncrementalBackupOps(repo: repo).createBackup(to: path)
    }

    public func verifyBackup(url: String) throws -> BundleOps.BundleReport {
        try IncrementalBackupOps(repo: repo).verifyBackup(url: url)
    }

    @discardableResult
    public func restoreBackup(url: String) throws -> BundleOps.BundleReport {
        try IncrementalBackupOps(repo: repo).restoreBackup(url: url)
    }

    public func backups() throws -> [IncrementalBackupOps.BackupManifest] {
        try IncrementalBackupOps(repo: repo).backups()
    }
}
