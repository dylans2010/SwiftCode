import Foundation
import Testing
@testable import SpacesEngine

@Suite struct HardeningTests {
    @Test func commitWithMetadataStoresCategoryAnnotationsTrailers() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "base")
        try SpacesTestSupport.write("2", to: api.repo.worktreeURL.appendingPathComponent("f"))
        _ = try api.stageAll()
        let metadata = CommitMetadata(trailers: ["Ticket": "ABC-1"], category: "feat", annotations: ["reviewed"])
        let result = try api.commitWithMetadata(message: "add feature", metadata: metadata)
        let payload = try api.repo.commitObject(result.oid)
        #expect(payload.metadata.category == "feat")
        #expect(payload.metadata.annotations == ["reviewed"])
        #expect(payload.metadata.trailers["Ticket"] == "ABC-1")
    }

    @Test func commitValidationBlocksWhenPoliciesExist() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "base")
        try api.setCommitPolicies([
            ValidationPolicyOps.PolicyRule(id: "msg", kind: .messagePattern, pattern: "^ABC-")
        ])
        try SpacesTestSupport.write("2", to: api.repo.worktreeURL.appendingPathComponent("f"))
        _ = try api.stageAll()
        var blocked = false
        do {
            _ = try api.commit(message: "lowercase message")
        } catch {
            blocked = true
        }
        #expect(blocked)
        let result = try api.commit(message: "ABC-1 allowed change")
        #expect(result.oid.hex.count == 64)
    }

    @Test func commitValidationIsNoopWithoutPolicies() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "base")
        try SpacesTestSupport.write("2", to: api.repo.worktreeURL.appendingPathComponent("f"))
        _ = try api.stageAll()
        let result = try api.commit(message: "any message at all")
        #expect(result.oid.hex.count == 64)
    }

    @Test func signCommitWithNamedIdentityVerifies() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "base")
        let signed = try api.signCommit(rev: "HEAD", identity: "release")
        #expect(!signed.signature.isEmpty)
        #expect(try api.verifyCommitSignature(rev: "HEAD"))
        #expect(try api.signingIdentities().contains("release"))
        let payload = try api.repo.commitObject(signed.oid)
        #expect(payload.metadata.signature == signed.signature)
        #expect(payload.metadata.trailers["signing-identity"] == "release")
        let defaultSigned = try api.signCommit(rev: "HEAD")
        #expect(try api.verifyCommitSignature(rev: "HEAD"))
        #expect(try api.repo.commitObject(defaultSigned.oid).metadata.trailers["signing-identity"] == "default")
    }

    @Test func addAnnotationRewritesCommitAndUpdatesRef() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let first = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "base")
        let rewritten = try api.addAnnotation(rev: "HEAD", annotation: "needs-backport")
        #expect(rewritten != first)
        #expect(try api.repo.refs.headOID(objects: api.repo.objects) == rewritten)
        let payload = try api.repo.commitObject(rewritten)
        #expect(payload.metadata.annotations.contains("needs-backport"))
        #expect(payload.message == "base")
        #expect(payload.tree == (try api.repo.commitObject(first)).tree)
    }

    @Test func compareCommitsReportsDiffsAndMetadataDifferences() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let first = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "base")
        try SpacesTestSupport.write("2", to: api.repo.worktreeURL.appendingPathComponent("f"))
        _ = try api.stageAll()
        let second = try api.commitWithMetadata(
            message: "change f",
            metadata: CommitMetadata(trailers: [:], category: "fix", annotations: ["hotfix"])).oid
        let comparison = try api.compareCommits(from: first.hex, to: second.hex)
        #expect(comparison.diffs.contains { $0.newPath == "f" && $0.status == .modified })
        #expect(comparison.metadataDifferences.contains("category differs"))
        #expect(comparison.metadataDifferences.contains("message differs"))
        #expect(comparison.metadataDifferences.contains("annotation added: hotfix"))
    }

    @Test func branchOwnershipRoundTrips() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "base")
        try api.setBranchOwner(branch: "main", owner: "dylan")
        #expect(try api.branchOwner(branch: "main") == "dylan")
        #expect(try api.branchOwner(branch: "missing") == nil)
    }

    @Test func branchExpirationListsOnlyExpiredBranches() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "base")
        try api.setBranchExpiration(branch: "main", date: Date(timeIntervalSince1970: 1))
        try api.createBranch("future")
        try api.setBranchExpiration(branch: "future", date: Date(timeIntervalSinceNow: 3600))
        let expired = try api.expiredBranches()
        #expect(expired.contains { $0.branch == "main" && $0.tipCommitTimestamp > 0 })
        #expect(!expired.contains { $0.branch == "future" })
    }

    @Test func protectedBranchDeleteIsDeniedAndAudited() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "base")
        try api.createBranch("side")
        try api.switchTo("side")
        try api.protectBranch(branch: "main", rules: [
            ProtectedHistoryOps.ProtectedRefRule(pattern: "main", allowForcePush: false, allowDelete: false)
        ])
        #expect(try api.branchProtection(branch: "main").count == 1)
        var denied = false
        do {
            try api.deleteBranch("main")
        } catch {
            denied = true
        }
        #expect(denied)
        #expect(try api.branches().contains { $0.name == "main" })
        let events = try api.auditEvents(limit: 20)
        #expect(events.contains { $0.operation == "branch-delete" && $0.result.contains("denied") })
        try api.deleteBranch("side", force: true)
        let after = try api.auditEvents(limit: 20)
        #expect(after.contains { $0.operation == "branch-delete" && $0.result == "success" })
    }

    @Test func branchActivityCountsCommitsAndReflog() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "one")
        _ = try SpacesTestSupport.commitFiles(api, ["f": "2"], message: "two")
        let activity = try api.branchActivity(branch: "main")
        #expect(activity.commitCount == 2)
        #expect(activity.reflogEntries >= 2)
        #expect(activity.lastCommitTimestamp > 0)
    }

    @Test func branchSyncReportWithoutUpstreamHasNoUpstream() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "base")
        let report = try api.branchSyncReport(branch: "main")
        #expect(!report.hasUpstream)
        #expect(report.upstream == nil)
        #expect(report.ahead == 0)
        #expect(report.behind == 0)
    }

    @Test func conflictProvenanceCarriesOriginsAndCategory() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let base = try SpacesTestSupport.commitFiles(api, ["f": "base\n"], message: "base")
        try api.createBranch("side")
        try api.switchTo("side")
        let theirs = try SpacesTestSupport.commitFiles(api, ["f": "side\n"], message: "side")
        try api.switchTo("main")
        let ours = try SpacesTestSupport.commitFiles(api, ["f": "main\n"], message: "main")
        let outcome = try api.merge("side")
        #expect(!outcome.conflicts.isEmpty)
        let provenance = try api.conflictProvenance()
        #expect(provenance.count == 1)
        let entry = provenance[0]
        #expect(entry.path == "f")
        #expect(entry.category == .content)
        #expect(entry.oursOID == ours)
        #expect(entry.theirsOID == theirs)
        #expect(entry.baseOID == base)
        #expect(!entry.resolved)
        let history = try api.conflictHistory()
        #expect(history.contains { $0.resolution == "unresolved" && $0.paths == ["f"] && $0.categories == ["content"] && $0.theirs == theirs.hex })
        try SpacesTestSupport.write("resolved\n", to: api.repo.worktreeURL.appendingPathComponent("f"))
        _ = try api.add("f")
        _ = try api.mergeContinue()
        let resolvedHistory = try api.conflictHistory()
        #expect(resolvedHistory.contains { $0.resolution == "resolved" && $0.paths == ["f"] })
    }

    @Test func resolutionPolicyAutoResolvesConflictTakeOurs() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "base\n"], message: "base")
        try api.createBranch("side")
        try api.switchTo("side")
        _ = try SpacesTestSupport.commitFiles(api, ["f": "side\n"], message: "side")
        try api.switchTo("main")
        _ = try SpacesTestSupport.commitFiles(api, ["f": "main\n"], message: "main")
        try api.setResolutionPolicy(path: "f", resolution: .takeOurs)
        #expect(try api.resolutionPolicies().contains { $0.path == "f" && $0.resolution == .takeOurs })
        let outcome = try api.merge("side")
        #expect(outcome.conflicts.isEmpty)
        #expect(try String(contentsOf: url.appendingPathComponent("f"), encoding: .utf8) == "main\n")
    }

    @Test func binaryDiffCarriesSizeAndDigestMetadata() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        try Data([0x00, 0x01, 0x02, 0x03]).write(to: url.appendingPathComponent("bin.dat"))
        _ = try api.stageAll()
        let first = try api.commit(message: "add binary").oid
        try Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05]).write(to: url.appendingPathComponent("bin.dat"))
        _ = try api.stageAll()
        _ = try api.commit(message: "grow binary")
        let diffs = try api.diff(first.hex, "HEAD")
        #expect(diffs.count == 1)
        let diff = diffs[0]
        #expect(diff.isBinary)
        #expect(diff.oldSize == 4)
        #expect(diff.newSize == 6)
        #expect(diff.oldDigest != nil)
        #expect(diff.newDigest != nil)
        #expect(diff.oldDigest != diff.newDigest)
    }

    @Test func compareDirectoriesCountsPerDirectory() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let first = try SpacesTestSupport.commitFiles(api, ["a.txt": "1", "sub/b.txt": "1"], message: "base")
        _ = try SpacesTestSupport.commitFiles(api, ["a.txt": "2", "sub/c.txt": "3"], message: "change")
        let fromTree = try api.repo.commitObject(first).tree
        let head = try api.repo.refs.headOID(objects: api.repo.objects)!
        let toTree = try api.repo.commitObject(head).tree
        let comparisons = try api.compareDirectories(from: fromTree, to: toTree)
        let sub = comparisons.first { $0.directory == "sub" }
        #expect(sub?.added == 1)
        #expect(sub?.removed == 0)
        let root = comparisons.first { $0.directory == "" }
        #expect(root?.added == 1)
        #expect(root?.changed == 1)
    }

    @Test func similarityRenameDetectedWithMeasuredRatio() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let first = try SpacesTestSupport.commitFiles(
            api, ["old.txt": "one\ntwo\nthree\nfour\n"], message: "base")
        try api.remove("old.txt")
        try SpacesTestSupport.write("one\ntwo\nthree\nFIVE\n", to: api.repo.worktreeURL.appendingPathComponent("new.txt"))
        _ = try api.stageAll()
        _ = try api.commit(message: "rename with edit")
        let diffs = try api.compareRevisions(from: first.hex, to: "HEAD")
        let renamed = diffs.first { $0.status == .renamed }
        #expect(renamed != nil)
        #expect(renamed?.oldPath == "old.txt")
        #expect(renamed?.newPath == "new.txt")
        let ratio = try #require(renamed?.similarityRatio)
        #expect(ratio >= 0.5)
        #expect(ratio < 1.0)
    }

    @Test func resumeFetchTransfersOnlyMissingObjects() throws {
        let (_, apiA, urlA) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(apiA, ["f": "1"], message: "one")
        let (_, apiB, _) = try SpacesTestSupport.makeRepo()
        try apiB.addRemote("origin", url: urlA.path)
        let first = try apiB.resumeFetch("origin")
        #expect(first.transferred > 0)
        #expect(first.failed.isEmpty)
        #expect(first.totalObjects == first.transferred + first.alreadyPresent + first.failed.count)
        let secondCommit = try SpacesTestSupport.commitFiles(apiA, ["f": "2"], message: "two")
        let second = try apiB.resumeFetch("origin")
        #expect(second.transferred > 0)
        #expect(second.failed.isEmpty)
        #expect(try apiB.repo.refs.readRef("refs/remotes/origin/main") == secondCommit)
        let health = try apiB.remoteHealth("origin")
        #expect(health.reachable)
        #expect(health.lastSync != nil)
        #expect(health.objectCount > 0)
        #expect(health.remoteRefCount >= 1)
    }

    @Test func remoteCancelLeavesPushResumable() throws {
        let (_, apiA, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(apiA, ["f": "1"], message: "push me")
        let (_, apiB, urlB) = try SpacesTestSupport.makeRepo()
        try apiA.addRemote("origin", url: urlB.path)
        try apiA.cancelRemoteTransfer("origin")
        var cancelled = false
        do {
            _ = try apiA.push("origin", refspec: "main")
        } catch SpacesError.cancelled {
            cancelled = true
        } catch {
            cancelled = false
        }
        #expect(cancelled)
        apiA.clearRemoteCancel("origin")
        let report = try apiA.resumePush("origin", refspec: "main")
        #expect(report.transferred > 0)
        #expect(report.failed.isEmpty)
        let head = try apiA.repo.refs.headOID(objects: apiA.repo.objects)
        #expect(try apiB.repo.refs.readRef("refs/heads/main") == head)
    }

    @Test func forcePushToProtectedBranchIsDenied() throws {
        let (_, apiA, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(apiA, ["f": "1"], message: "one")
        let (_, apiB, urlB) = try SpacesTestSupport.makeRepo()
        try apiA.addRemote("origin", url: urlB.path)
        _ = try apiA.push("origin", refspec: "main")
        _ = try SpacesTestSupport.commitFiles(apiB, ["g": "remote"], message: "remote work")
        _ = try SpacesTestSupport.commitFiles(apiA, ["f": "2"], message: "local two")
        try apiA.protectBranch(branch: "main", rules: [
            ProtectedHistoryOps.ProtectedRefRule(pattern: "main", allowForcePush: false, allowDelete: false)
        ])
        var denied = false
        do {
            _ = try apiA.push("origin", refspec: "main", force: true)
        } catch {
            denied = true
        }
        #expect(denied)
        let head = try apiA.repo.refs.headOID(objects: apiA.repo.objects)
        #expect(try apiB.repo.refs.readRef("refs/heads/main") != head)
        let events = try apiA.auditEvents(limit: 20)
        #expect(events.contains { $0.operation == "force-push" && $0.result.contains("denied") })
    }

    @Test func gcBudgetReportsOverageWithoutDeletingReachableObjects() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "base")
        try api.setRetentionPolicy(RetentionPolicyOps.RetentionPolicy(maxBytes: 1))
        let report = try api.gcWithBudget()
        #expect(report.maxBytes == 1)
        #expect(report.overBudgetBy > 0)
        #expect(report.reachable > 0)
        #expect(try api.log(limit: 10).count == 1)
    }

    @Test func duplicateContentReportCountsSharedSnapshotBlobs() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "shared contents"], message: "base")
        _ = try api.snapshot(message: "snap one")
        _ = try api.snapshot(message: "snap two")
        let report = try api.duplicateContentReport()
        #expect(report.snapshotCount == 2)
        #expect(report.sharedBlobCount >= 1)
        #expect(report.sharedBytes > 0)
        #expect(report.bytesSaved >= 0)
    }

    @Test func performanceDiagnosticsMeasuresRealOperations() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "base")
        let diagnostics = try api.performanceDiagnostics()
        #expect(diagnostics.statusMs >= 0)
        #expect(diagnostics.logMs >= 0)
        #expect(diagnostics.fsckMs >= 0)
        #expect(diagnostics.storageMs >= 0)
        #expect(diagnostics.timestamp > 0)
    }

    @Test func restoreVaultRetainsDiscardedContents() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "kept"], message: "base")
        try SpacesTestSupport.write("discarded", to: url.appendingPathComponent("f"))
        try api.restore("f")
        #expect(try String(contentsOf: url.appendingPathComponent("f"), encoding: .utf8) == "kept")
        let entries = try api.vaultEntries()
        #expect(entries.contains { $0.path == "f" })
    }

    @Test func mergeIsRecordedInAccessAudit() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["a": "1", "b": "1"], message: "base")
        try api.createBranch("feature")
        try api.switchTo("feature")
        _ = try SpacesTestSupport.commitFiles(api, ["a": "feature"], message: "feat a")
        try api.switchTo("main")
        _ = try SpacesTestSupport.commitFiles(api, ["b": "main"], message: "main b")
        let outcome = try api.merge("feature")
        #expect(outcome.conflicts.isEmpty)
        let events = try api.auditEvents(limit: 20)
        #expect(events.contains { $0.operation == "merge" && $0.result == "success" })
    }

    @Test func openExistingRepositoryRecoversAndReads() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f": "1"], message: "base")
        let reopened = try SpacesAPI.open(at: url.path)
        #expect(try reopened.status().branch == "main")
        #expect(try reopened.log(limit: 10).count == 1)
    }
}
