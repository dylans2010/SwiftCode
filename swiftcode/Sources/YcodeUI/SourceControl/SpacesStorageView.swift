import Foundation
import SwiftUI
import SpacesEngine

@Observable
@MainActor
final class SpacesStorageModel {
    let workspace: SpacesWorkspaceModel
    var error: String?
    var notice: String?
    var continuousConfig: ContinuousSnapshotOps.ContinuousConfig?
    var configEnabled = false
    var configIntervalMinutes = 60
    var configMaxSnapshots = 10
    var snapshots: [SnapshotOps.SnapshotInfo] = []
    var branchFromRev = ""
    var branchFromName = ""
    var checkoutRev = ""
    var verifyRev = ""
    var verifications: [SnapshotIntegrityOps.SnapshotVerification] = []
    var dedupReport: SnapshotDedupOps.DeduplicationReport?
    var retentionPolicy: RetentionPolicyOps.RetentionPolicy?
    var retentionMaxAgeDays = ""
    var retentionMaxCount = ""
    var retentionMaxBytes = ""
    var retentionPinned = ""
    var heatmap: StorageHeatmapOps.StorageHeatmap?
    var growthEstimate: PredictiveStorageOps.GrowthEstimate?
    var vaultPaths = ""
    var vaultReason = "retained"
    var vaultEntries: [RecoveryVaultOps.VaultEntry] = []
    var vaultRestoreId = ""
    var vaultRestorePath = ""
    var profiles: [CompactionProfileOps.CompactionProfile] = []
    var backupPath = ""
    var verifyBackupURL = ""
    var restoreBackupURL = ""
    var backups: [IncrementalBackupOps.BackupManifest] = []
    var backupReport: BundleOps.BundleReport?

    init(workspace: SpacesWorkspaceModel) {
        self.workspace = workspace
    }

    func refreshAll() {
        loadContinuousConfig()
        loadSnapshots()
        loadRetentionPolicy()
        loadHeatmap()
        loadVaultEntries()
        loadProfiles()
        loadBackups()
    }

    private func load<T: Sendable>(_ what: String, _ body: @escaping @Sendable (SpacesAPI) throws -> T, assign: @escaping @MainActor @Sendable (T) -> Void) {
        guard let api = workspace.api else { return }
        Task.detached {
            do {
                let value = try body(api)
                await MainActor.run { assign(value) }
            } catch {
                await MainActor.run { self.error = "\(what): \(error.localizedDescription)" }
            }
        }
    }

    private func perform(_ what: String, _ body: @escaping @Sendable (SpacesAPI) throws -> Void) {
        guard let api = workspace.api else { return }
        Task.detached {
            do { try body(api) } catch {
                await MainActor.run { self.error = "\(what): \(error.localizedDescription)" }
            }
            await MainActor.run { self.refreshAll() }
        }
    }

    func loadContinuousConfig() {
        load("continuous snapshot config", { try $0.continuousSnapshotConfig() }, assign: { config in
            self.continuousConfig = config
            self.configEnabled = config.enabled
            self.configIntervalMinutes = config.intervalMinutes
            self.configMaxSnapshots = config.maxSnapshots
        })
    }

    func loadSnapshots() {
        load("snapshots", { try $0.snapshots() }, assign: { self.snapshots = $0 })
    }

    func loadRetentionPolicy() {
        load("retention policy", { try $0.retentionPolicy() }, assign: { policy in
            self.retentionPolicy = policy
            self.retentionMaxAgeDays = policy.maxAgeDays.map { String($0) } ?? ""
            self.retentionMaxCount = policy.maxCount.map { String($0) } ?? ""
            self.retentionMaxBytes = policy.maxBytes.map { String($0) } ?? ""
            self.retentionPinned = policy.pinned.joined(separator: ", ")
        })
    }

    func loadHeatmap() {
        load("storage heatmap", { try $0.storageHeatmap() }, assign: { self.heatmap = $0 })
    }

    func loadVaultEntries() {
        load("vault entries", { try $0.vaultEntries() }, assign: { self.vaultEntries = $0 })
    }

    func loadProfiles() {
        load("compaction profiles", { try $0.compactionProfiles() }, assign: { self.profiles = $0 })
    }

    func loadBackups() {
        load("backups", { try $0.backups() }, assign: { self.backups = $0 })
    }

    func saveContinuousConfig() {
        let config = ContinuousSnapshotOps.ContinuousConfig(enabled: configEnabled, intervalMinutes: configIntervalMinutes, maxSnapshots: configMaxSnapshots)
        perform("save continuous snapshot config") { try $0.setContinuousSnapshotConfig(config) }
    }

    func captureIfDue() {
        guard let api = workspace.api else { return }
        Task.detached {
            do {
                let oid = try api.captureWorkspaceSnapshotIfDue()
                await MainActor.run {
                    if let oid {
                        self.notice = "Continuous snapshot captured: \(oid.hex.prefix(8))"
                    } else {
                        self.notice = "No snapshot due yet under the current continuous schedule"
                    }
                    self.loadSnapshots()
                }
            } catch {
                await MainActor.run { self.error = "capture workspace snapshot: \(error.localizedDescription)" }
            }
        }
    }

    func branchFromSnapshot() {
        let rev = branchFromRev
        let name = branchFromName
        guard !rev.isEmpty, !name.isEmpty else {
            error = "branch from snapshot: revision and branch name are both required"
            return
        }
        perform("branch from snapshot") { _ = try $0.branchFromSnapshot(rev: rev, name: name) }
        branchFromRev = ""
        branchFromName = ""
    }

    func checkoutSnapshot() {
        let rev = checkoutRev
        guard !rev.isEmpty else {
            error = "checkout snapshot: enter a snapshot revision first"
            return
        }
        perform("checkout snapshot") { try $0.checkoutSnapshot(rev: rev) }
        checkoutRev = ""
    }

    func verifySnapshot() {
        let rev = verifyRev
        guard !rev.isEmpty else {
            error = "verify snapshot: enter a snapshot revision first"
            return
        }
        load("verify snapshot", { try $0.verifySnapshot(rev) }, assign: { verification in
            self.verifications = [verification]
        })
    }

    func verifyAllSnapshots() {
        load("verify all snapshots", { try $0.verifyAllSnapshots() }, assign: { self.verifications = $0 })
    }

    func loadDedupReport() {
        load("snapshot deduplication report", { try $0.snapshotDeduplicationReport() }, assign: { self.dedupReport = $0 })
    }

    func saveRetentionPolicy() {
        let policy = RetentionPolicyOps.RetentionPolicy(
            maxAgeDays: Int(retentionMaxAgeDays),
            maxCount: Int(retentionMaxCount),
            maxBytes: Int64(retentionMaxBytes),
            pinned: retentionPinned.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
        perform("save retention policy") { try $0.setRetentionPolicy(policy) }
    }

    func applyRetentionPolicy() {
        guard let api = workspace.api else { return }
        Task.detached {
            do {
                let pruned = try api.applyRetentionPolicy()
                await MainActor.run {
                    self.notice = "Retention applied: pruned \(pruned.count) snapshot(s)"
                    self.loadSnapshots()
                }
            } catch {
                await MainActor.run { self.error = "apply retention policy: \(error.localizedDescription)" }
            }
        }
    }

    func recordStorageSample() {
        guard let api = workspace.api else { return }
        Task.detached {
            do {
                let sample = try api.recordStorageSample()
                let estimate = try api.storageGrowthEstimate()
                await MainActor.run {
                    self.notice = "Storage sample recorded: \(sample.objectCount) objects, \(sample.bytes) bytes"
                    self.growthEstimate = estimate
                }
            } catch {
                await MainActor.run { self.error = "record storage sample: \(error.localizedDescription)" }
            }
        }
    }

    func loadGrowthEstimate() {
        load("storage growth estimate", { try $0.storageGrowthEstimate() }, assign: { self.growthEstimate = $0 })
    }

    func retainInVault() {
        let paths = vaultPaths.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let reason = vaultReason
        guard !paths.isEmpty else {
            error = "recovery vault: enter at least one path first"
            return
        }
        perform("vault retain") { _ = try $0.vaultRetain(paths: paths, reason: reason) }
        vaultPaths = ""
    }

    func restoreFromVault() {
        let id = vaultRestoreId
        guard !id.isEmpty else {
            error = "restore from vault: enter a vault entry id first"
            return
        }
        let path = vaultRestorePath.isEmpty ? nil : vaultRestorePath
        guard let api = workspace.api else { return }
        Task.detached {
            do {
                let restored = try api.restoreFromVault(entry: id, path: path)
                await MainActor.run {
                    self.notice = "Restored from vault: \(restored)"
                    self.loadVaultEntries()
                }
            } catch {
                await MainActor.run { self.error = "restore from vault: \(error.localizedDescription)" }
            }
        }
    }

    func applyCompactionProfile(_ profile: CompactionProfileOps.CompactionProfile) {
        let name = profile.name
        guard let api = workspace.api else { return }
        Task.detached {
            do {
                let result = try api.applyCompactionProfile(name: name)
                await MainActor.run {
                    self.notice = "Compaction \(name): \(result.objectsBefore) → \(result.objectsAfter) objects, pruned \(result.pruned)"
                    self.loadHeatmap()
                }
            } catch {
                await MainActor.run { self.error = "apply compaction profile: \(error.localizedDescription)" }
            }
        }
    }

    func createBackup() {
        let path = backupPath
        guard !path.isEmpty else {
            error = "create backup: enter a backup destination path first"
            return
        }
        guard let api = workspace.api else { return }
        Task.detached {
            do {
                let manifest = try api.createBackup(to: path)
                await MainActor.run {
                    self.notice = "Backup \(manifest.id) created with \(manifest.objects.count) objects"
                    self.loadBackups()
                }
            } catch {
                await MainActor.run { self.error = "create backup: \(error.localizedDescription)" }
            }
        }
    }

    func runVerifyBackup() {
        let url = verifyBackupURL
        guard !url.isEmpty else {
            error = "verify backup: enter a backup path first"
            return
        }
        load("verify backup", { try $0.verifyBackup(url: url) }, assign: { self.backupReport = $0 })
    }

    func runRestoreBackup() {
        let url = restoreBackupURL
        guard !url.isEmpty else {
            error = "restore backup: enter a backup path first"
            return
        }
        guard let api = workspace.api else { return }
        Task.detached {
            do {
                let report = try api.restoreBackup(url: url)
                await MainActor.run {
                    self.backupReport = report
                    self.notice = "Backup restored: \(report.objectCount) objects"
                    self.refreshAll()
                }
            } catch {
                await MainActor.run { self.error = "restore backup: \(error.localizedDescription)" }
            }
        }
    }

    static func dateString(_ timestamp: Int64) -> String {
        Date(timeIntervalSince1970: TimeInterval(timestamp)).formatted(date: .abbreviated, time: .shortened)
    }
}

struct SpacesStorageView: View {
    @State private var model: SpacesStorageModel

    init(workspace: SpacesWorkspaceModel) {
        _model = State(initialValue: SpacesStorageModel(workspace: workspace))
    }

    var body: some View {
        Form {
            if let error = model.error {
                Section {
                    HStack {
                        Text(error).foregroundStyle(.red)
                        Spacer()
                        Button("Dismiss") { model.error = nil }
                    }
                }
            }
            if let notice = model.notice {
                Section {
                    HStack {
                        Text(notice)
                        Spacer()
                        Button("Dismiss") { model.notice = nil }
                    }
                }
            }
            Section("Continuous Snapshots") {
                Toggle("Enabled", isOn: $model.configEnabled)
                Stepper("Interval: \(model.configIntervalMinutes) minutes", value: $model.configIntervalMinutes, in: 1...1440)
                Stepper("Maximum snapshots: \(model.configMaxSnapshots)", value: $model.configMaxSnapshots, in: 1...500)
                HStack {
                    Button("Save Continuous Config") { model.saveContinuousConfig() }
                    Button("Capture If Due") { model.captureIfDue() }
                }
            }
            Section("Snapshots") {
                HStack {
                    TextField("Snapshot revision", text: $model.branchFromRev)
                    TextField("New branch name", text: $model.branchFromName)
                    Button("Branch From Snapshot") { model.branchFromSnapshot() }
                        .disabled(model.branchFromRev.isEmpty || model.branchFromName.isEmpty)
                }
                HStack {
                    TextField("Snapshot revision to check out", text: $model.checkoutRev)
                    Button("Checkout Snapshot") { model.checkoutSnapshot() }
                        .disabled(model.checkoutRev.isEmpty)
                }
                HStack {
                    TextField("Snapshot revision to verify", text: $model.verifyRev)
                    Button("Verify Snapshot") { model.verifySnapshot() }
                        .disabled(model.verifyRev.isEmpty)
                    Button("Verify All Snapshots") { model.verifyAllSnapshots() }
                }
                ForEach(Array(model.verifications.enumerated()), id: \.offset) { _, verification in
                    HStack {
                        Text(verification.oid.hex.prefix(8)).font(.caption.monospaced())
                        Spacer()
                        Text(verification.valid ? "valid" : "invalid").foregroundStyle(verification.valid ? .green : .red).font(.caption)
                        Text("\(verification.checkedObjects) objects checked").font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(Array(verification.issues.enumerated()), id: \.offset) { _, issue in
                        Text(issue).font(.caption).foregroundStyle(.orange)
                    }
                }
                Button("Snapshot Deduplication Report") { model.loadDedupReport() }
                if let report = model.dedupReport {
                    Text("\(report.snapshotCount) snapshots • naive \(report.naiveBytes) bytes • shared \(report.sharedBytes) bytes • saved \(report.bytesSaved) bytes (\(report.sharedBlobCount) shared blobs)")
                        .font(.caption)
                    ForEach(Array(report.perSnapshot.enumerated()), id: \.offset) { _, entry in
                        Text("\(entry.oid.hex.prefix(8)) — \(entry.message): \(entry.naiveBytes) bytes")
                            .font(.caption.monospaced())
                    }
                }
                ForEach(Array(model.snapshots.enumerated()), id: \.offset) { _, snapshot in
                    HStack {
                        Text(snapshot.message).font(.subheadline)
                        Spacer()
                        Text(snapshot.oid.hex.prefix(8)).font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                }
            }
            Section("Retention Policy") {
                HStack {
                    TextField("Max age (days, blank = none)", text: $model.retentionMaxAgeDays)
                    TextField("Max count (blank = none)", text: $model.retentionMaxCount)
                    TextField("Max bytes (blank = none)", text: $model.retentionMaxBytes)
                }
                TextField("Pinned revisions (comma separated)", text: $model.retentionPinned)
                HStack {
                    Button("Save Retention Policy") { model.saveRetentionPolicy() }
                    Button("Apply Retention Policy") { model.applyRetentionPolicy() }
                }
            }
            Section("Storage Heatmap") {
                Button("Refresh Heatmap") { model.loadHeatmap() }
                if let heatmap = model.heatmap {
                    Text("Total \(heatmap.totalBytes) bytes in \(heatmap.totalObjects) objects • reachable \(heatmap.reachableBytes) • unreachable \(heatmap.unreachableBytes)")
                        .font(.caption)
                    Text("By type").font(.subheadline)
                    ForEach(Array(heatmap.byType.enumerated()), id: \.offset) { _, bucket in
                        heatmapRow(bucket)
                    }
                    Text("By size band").font(.subheadline)
                    ForEach(Array(heatmap.sizeBands.enumerated()), id: \.offset) { _, bucket in
                        heatmapRow(bucket)
                    }
                    Text("By age band").font(.subheadline)
                    ForEach(Array(heatmap.ageBands.enumerated()), id: \.offset) { _, bucket in
                        heatmapRow(bucket)
                    }
                }
            }
            Section("Storage Growth") {
                HStack {
                    Button("Record Storage Sample") { model.recordStorageSample() }
                    Button("Refresh Growth Estimate") { model.loadGrowthEstimate() }
                }
                if let estimate = model.growthEstimate {
                    Text("Daily growth: \(estimate.dailyGrowthBytes, format: .number) bytes/day (\(estimate.method))")
                        .font(.caption)
                    if let projected = estimate.projectedBytesAt30Days {
                        Text("Projected in 30 days: \(projected) bytes").font(.caption)
                    }
                    Text(estimate.recommendation).font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Recovery Vault") {
                HStack {
                    TextField("Paths (comma separated)", text: $model.vaultPaths)
                    TextField("Reason", text: $model.vaultReason)
                    Button("Retain In Vault") { model.retainInVault() }
                        .disabled(model.vaultPaths.isEmpty)
                }
                ForEach(Array(model.vaultEntries.enumerated()), id: \.offset) { _, entry in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(entry.path).font(.subheadline)
                            Text("\(entry.reason) • \(entry.size) bytes • \(SpacesStorageModel.dateString(entry.timestamp))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(entry.id).font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                }
                HStack {
                    TextField("Vault entry id", text: $model.vaultRestoreId)
                    TextField("Restore to path (optional)", text: $model.vaultRestorePath)
                    Button("Restore From Vault") { model.restoreFromVault() }
                        .disabled(model.vaultRestoreId.isEmpty)
                }
            }
            Section("Compaction Profiles") {
                ForEach(Array(model.profiles.enumerated()), id: \.offset) { _, profile in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(profile.name).font(.subheadline)
                            Text("kind \(profile.kind) • rebuild index: \(profile.rebuildIndex ? "yes" : "no") • prune unreachable: \(profile.pruneUnreachable ? "yes" : "no") • prune older than \(profile.pruneDays) days")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Apply") { model.applyCompactionProfile(profile) }
                            .controlSize(.small)
                    }
                }
            }
            Section("Incremental Backups") {
                HStack {
                    TextField("Backup destination path", text: $model.backupPath)
                    Button("Create Backup") { model.createBackup() }
                        .disabled(model.backupPath.isEmpty)
                }
                ForEach(Array(model.backups.enumerated()), id: \.offset) { _, backup in
                    HStack {
                        Text(backup.id).font(.callout.monospaced())
                        Spacer()
                        Text("\(backup.objects.count) objects").font(.caption).foregroundStyle(.secondary)
                        Text(SpacesStorageModel.dateString(backup.timestamp)).font(.caption).foregroundStyle(.secondary)
                    }
                }
                HStack {
                    TextField("Backup path to verify", text: $model.verifyBackupURL)
                    Button("Verify Backup") { model.runVerifyBackup() }
                        .disabled(model.verifyBackupURL.isEmpty)
                }
                HStack {
                    TextField("Backup path to restore", text: $model.restoreBackupURL)
                    Button("Restore Backup") { model.runRestoreBackup() }
                        .disabled(model.restoreBackupURL.isEmpty)
                }
                if let report = model.backupReport {
                    Text("Bundle: \(report.objectCount) objects, created \(SpacesStorageModel.dateString(report.created))")
                        .font(.caption)
                    ForEach(Array(report.refs.keys.sorted().enumerated()), id: \.offset) { _, ref in
                        Text("\(ref) → \(report.refs[ref] ?? "")").font(.caption.monospaced())
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { model.refreshAll() }
    }

    private func heatmapRow(_ bucket: StorageHeatmapOps.Bucket) -> some View {
        HStack {
            Text(bucket.label).font(.caption)
            Spacer()
            Text("\(bucket.count) objects").font(.caption).foregroundStyle(.secondary)
            Text("\(bucket.bytes) bytes").font(.caption.monospaced()).foregroundStyle(.secondary)
        }
    }
}
