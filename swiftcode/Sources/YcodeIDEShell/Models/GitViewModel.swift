import Foundation
import Observation
import YcodeIDECore
import SwiftCodeSDK

/// View model for the source-control navigator. Routes every operation to
/// either the Git service or the native Spaces service depending on the
/// persistent "Source Control System" preference (Settings → Source Control).
@Observable
@MainActor
public class GitViewModel {
    public var status: GitStatusSnapshot?
    public var history: [GitCommit] = []
    public var branches: [GitBranch] = []
    public var isScanning = false
    public var isGitInstalled = false
    public var repositoryURL: URL?

    /// True when the Spaces source-control system is selected or when the repository has a .spaces metadata folder.
    public var usesSpaces: Bool {
        if Preferences.shared.usesSpacesSourceControl { return true }
        if let url = repositoryURL {
            let metaURL = url.appendingPathComponent(".spaces")
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: metaURL.path, isDirectory: &isDir), isDir.boolValue {
                return true
            }
        }
        return false
    }

    public func initializeSpaces() async throws {
        guard let url = repositoryURL else { return }
        try await SpacesService.shared.initialize(at: url)
        await refreshInstallationStatus()
        await refreshStatus()
    }

    public init() {}

    public func refreshInstallationStatus() async {
        if usesSpaces {
            isGitInstalled = await SpacesService.shared.isSpacesAvailable()
        } else {
            isGitInstalled = await GitService.shared.isGitInstalled()
        }
    }

    public func refreshStatus() async {
        guard let url = repositoryURL else { return }
        isScanning = true
        do {
            if usesSpaces {
                status = try await SpacesService.shared.getStatus(for: url)
                history = try await SpacesService.shared.getLog(repositoryURL: url)
                branches = try await SpacesService.shared.getBranches(repositoryURL: url)
            } else {
                status = try await GitService.shared.getStatus(for: url)
                history = try await GitService.shared.getLog(repositoryURL: url)
                branches = try await GitService.shared.getBranches(repositoryURL: url)
            }
        } catch {
            LoggingTool.error("Source control status failed: \(error)")
        }
        isScanning = false
    }

    public func stage(_ file: GitFileStatus) async {
        guard let url = repositoryURL else { return }
        if usesSpaces {
            try? await SpacesService.shared.stage(path: URL(fileURLWithPath: file.path), repositoryURL: url)
        } else {
            try? await GitService.shared.stage(path: URL(fileURLWithPath: file.path), repositoryURL: url)
        }
        await refreshStatus()
    }

    public func unstage(_ file: GitFileStatus) async {
        guard let url = repositoryURL else { return }
        if usesSpaces {
            try? await SpacesService.shared.unstage(path: URL(fileURLWithPath: file.path), repositoryURL: url)
        } else {
            try? await GitService.shared.unstage(path: URL(fileURLWithPath: file.path), repositoryURL: url)
        }
        await refreshStatus()
    }

    public func discardChanges(_ file: GitFileStatus) async {
        guard let url = repositoryURL else { return }
        if usesSpaces {
            try? await SpacesService.shared.discardChanges(path: URL(fileURLWithPath: file.path), repositoryURL: url)
        } else {
            try? await GitService.shared.discardChanges(path: URL(fileURLWithPath: file.path), repositoryURL: url)
        }
        await refreshStatus()
    }

    public func commit(message: String) async {
        guard let url = repositoryURL else { return }
        if usesSpaces {
            try? await SpacesService.shared.commit(message: message, repositoryURL: url)
        } else {
            try? await GitService.shared.commit(message: message, repositoryURL: url)
        }
        await refreshStatus()
    }

    public func refreshBranches() {
        Task {
            await refreshStatus()
        }
    }

    public func createBranch(named name: String) {
        guard let url = repositoryURL else { return }
        Task {
            do {
                if usesSpaces {
                    try await SpacesService.shared.createBranch(name: name, repositoryURL: url)
                } else {
                    try await GitService.shared.createBranch(name: name, repositoryURL: url)
                }
                await refreshStatus()
            } catch {
                LoggingTool.error("Branch creation failed: \(error)")
            }
        }
    }

    public func checkout(_ branch: GitBranch) {
        guard let url = repositoryURL else { return }
        Task {
            do {
                if usesSpaces {
                    try await SpacesService.shared.checkout(branch: branch.name, repositoryURL: url)
                } else {
                    try await GitService.shared.checkout(branch: branch.name, repositoryURL: url)
                }
                await refreshStatus()
            } catch {
                LoggingTool.error("Checkout failed: \(error)")
            }
        }
    }

    public func deleteBranch(_ branch: GitBranch) {
        guard let url = repositoryURL else { return }
        Task {
            do {
                if usesSpaces {
                    try await SpacesService.shared.deleteBranch(name: branch.name, repositoryURL: url)
                } else {
                    try await GitService.shared.deleteBranch(name: branch.name, repositoryURL: url)
                }
                await refreshStatus()
            } catch {
                LoggingTool.error("Branch deletion failed: \(error)")
            }
        }
    }

    public func getDiff() async -> [GitDiffHunk] {
        guard let url = repositoryURL else { return [] }
        if usesSpaces {
            return (try? await SpacesService.shared.getDiff(repositoryURL: url)) ?? []
        }
        return (try? await GitService.shared.getDiff(repositoryURL: url)) ?? []
    }

    public func rollback(to sha: String) async throws {
        guard let url = repositoryURL else { return }
        if usesSpaces {
            try await SpacesService.shared.rollback(to: sha, repositoryURL: url)
        } else {
            try await GitService.shared.rollback(to: sha, repositoryURL: url)
        }
        await refreshStatus()
    }

    public func forcePush(branch: String) async throws {
        guard let url = repositoryURL else { return }
        if usesSpaces {
            try await SpacesService.shared.forcePush(branch: branch, repositoryURL: url)
        } else {
            try await GitService.shared.forcePush(branch: branch, repositoryURL: url)
        }
        await refreshStatus()
    }

    public func push() async throws {
        guard let url = repositoryURL else { return }
        if usesSpaces {
            try await SpacesService.shared.push(repositoryURL: url)
        } else {
            try await GitService.shared.push(repositoryURL: url)
        }
        await refreshStatus()
    }

    public func fetch() async throws {
        guard let url = repositoryURL else { return }
        if usesSpaces {
            try await SpacesService.shared.fetch(repositoryURL: url)
        }
    }

    public func pull() async throws {
        guard let url = repositoryURL else { return }
        if usesSpaces {
            try await SpacesService.shared.pull(repositoryURL: url)
        }
    }

    public func merge(branch: String) async throws {
        guard let url = repositoryURL else { return }
        if usesSpaces {
            try await SpacesService.shared.merge(branch, repositoryURL: url)
        }
        await refreshStatus()
    }

    public func stash(message: String = "wip") async throws {
        guard let url = repositoryURL else { return }
        if usesSpaces {
            try await SpacesService.shared.stash(message: message, repositoryURL: url)
        }
        await refreshStatus()
    }

    public func rebase(onto: String) async throws {
        guard let url = repositoryURL else { return }
        if usesSpaces {
            try await SpacesService.shared.rebase(onto: onto, repositoryURL: url)
        }
        await refreshStatus()
    }

    public func abortMerge() async throws {
        guard let url = repositoryURL else { return }
        if usesSpaces {
            try await SpacesService.shared.mergeAbort(repositoryURL: url)
        }
        await refreshStatus()
    }

    public func continueMerge() async throws {
        guard let url = repositoryURL else { return }
        if usesSpaces {
            try await SpacesService.shared.mergeContinue(repositoryURL: url)
        }
        await refreshStatus()
    }
}
