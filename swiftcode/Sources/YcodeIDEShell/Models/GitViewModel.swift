import Foundation
import Observation
import YcodeIDECore
import YcodeAssistant
import SwiftCodeSDK




public enum SourceControlProvider: String, Sendable {
    case git = "git"
    case spaces = "spaces"
}

@Observable
@MainActor
public class GitViewModel {
    public var status: GitStatusSnapshot?
    public var history: [GitCommit] = []
    public var branches: [GitBranch] = []
    public var isScanning = false
    public var isGitInstalled = false
    public var repositoryURL: URL?

    public var isBusy = false
    public var currentOperation: String?
    public var lastError: String?
    private var cancellationRequested = false

    /// Per-repository provider override ("git" or "spaces"), or nil for auto.
    public static func providerOverride(for url: URL) -> String? {
        UserDefaults.standard.string(forKey: "SwiftCode.scmProvider.\(url.standardizedFileURL.path)")
    }

    public static func setProviderOverride(_ value: String?, for url: URL) {
        let key = "SwiftCode.scmProvider.\(url.standardizedFileURL.path)"
        if let value { UserDefaults.standard.set(value, forKey: key) }
        else { UserDefaults.standard.removeObject(forKey: key) }
    }

    public static func resolveProvider(for url: URL) -> SourceControlProvider {
        if let override = providerOverride(for: url) {
            if override == "spaces" { return .spaces }
            if override == "git" { return .git }
        }
        let hasGit = FileManager.default.fileExists(atPath: url.appendingPathComponent(".git").path)
        var spacesDir: ObjCBool = false
        let hasSpaces = FileManager.default.fileExists(atPath: url.appendingPathComponent(".spaces").path, isDirectory: &spacesDir) && spacesDir.boolValue
        if hasGit && hasSpaces {
            return Preferences.shared.usesSpacesSourceControl ? .spaces : .git
        }
        if hasSpaces {
            return .spaces
        }
        if hasGit {
            return .git
        }
        return Preferences.shared.usesSpacesSourceControl ? .spaces : .git
    }

    public var usesSpaces: Bool {
        if let url = repositoryURL {
            return Self.resolveProvider(for: url) == .spaces
        }
        return Preferences.shared.usesSpacesSourceControl
    }

    public func cancelCurrentOperation() {
        cancellationRequested = true
    }

    private func beginOperation(_ name: String) throws {
        guard !isBusy else {
            throw GitError.commandFailed(command: name, exitCode: 1, output: "Another source-control operation (\(currentOperation ?? "unknown")) is already running.")
        }
        isBusy = true
        currentOperation = name
        lastError = nil
        cancellationRequested = false
    }

    private func endOperation() {
        isBusy = false
        currentOperation = nil
    }

    private func runGit(_ arguments: [String], workingDirectory: URL) async throws -> String {
        let gitPath = AppSettings.shared.gitPath.isEmpty ? "/usr/bin/git" : AppSettings.shared.gitPath
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gitPath)
        process.arguments = arguments
        process.currentDirectoryURL = workingDirectory
        process.standardInput = FileHandle.nullDevice
        var environment = ProcessInfo.processInfo.environment
        environment["GIT_EDITOR"] = "true"
        environment["GIT_SEQUENCE_EDITOR"] = "true"
        environment["GIT_TERMINAL_PROMPT"] = "0"
        process.environment = environment
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        let stdoutTask = Task.detached { stdoutPipe.fileHandleForReading.readDataToEndOfFile() }
        let stderrTask = Task.detached { stderrPipe.fileHandleForReading.readDataToEndOfFile() }
        do {
            try process.run()
        } catch {
            stdoutTask.cancel()
            stderrTask.cancel()
            throw error
        }
        while process.isRunning {
            if Task.isCancelled || cancellationRequested {
                process.terminate()
                stdoutTask.cancel()
                stderrTask.cancel()
                throw CancellationError()
            }
            try await Task.sleep(for: .milliseconds(25))
        }
        let stdout = String(data: await stdoutTask.value, encoding: .utf8) ?? ""
        let stderr = String(data: await stderrTask.value, encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw GitError.commandFailed(command: "git \(arguments.joined(separator: " "))", exitCode: process.terminationStatus, output: stderr.isEmpty ? stdout : stderr)
        }
        return stdout
    }

    public func initializeSpaces() async throws {
        guard let url = repositoryURL else { return }
        try await SpacesService.shared.initialize(at: url, defaultBranch: SpacesService.defaultBranchSetting)
        await refreshInstallationStatus()
        await refreshStatus()
    }

    public init() {}

    public func refreshInstallationStatus() async {
        if usesSpaces, let url = repositoryURL {
            isGitInstalled = await SpacesService.shared.isSpacesAvailable(at: url)
        } else {
            isGitInstalled = await SwiftCodeSDK.GitService.shared.isGitInstalled()
        }
    }

    public func refreshStatus() async {
        guard let url = repositoryURL else { return }
        guard !isScanning else { return }
        isScanning = true
        defer { isScanning = false }
        do {
            if usesSpaces {
                status = try await SpacesService.shared.getStatus(for: url)
                history = try await SpacesService.shared.getLog(repositoryURL: url)
                branches = try await SpacesService.shared.getBranches(repositoryURL: url)
            } else {
                status = try await SwiftCodeSDK.GitService.shared.getStatus(for: url)
                history = try await SwiftCodeSDK.GitService.shared.getLog(repositoryURL: url)
                branches = try await SwiftCodeSDK.GitService.shared.getBranches(repositoryURL: url)
            }
        } catch {
            lastError = error.localizedDescription
            LoggingTool.error("Source control status failed: \(error)")
        }
    }

    public func stage(_ file: GitFileStatus) async {
        guard let url = repositoryURL else { return }
        if usesSpaces {
            try? await SpacesService.shared.stage(path: URL(fileURLWithPath: file.path), repositoryURL: url)
        } else {
            try? await SwiftCodeSDK.GitService.shared.stage(path: URL(fileURLWithPath: file.path), repositoryURL: url)
        }
        await refreshStatus()
    }

    public func unstage(_ file: GitFileStatus) async {
        guard let url = repositoryURL else { return }
        if usesSpaces {
            try? await SpacesService.shared.unstage(path: URL(fileURLWithPath: file.path), repositoryURL: url)
        } else {
            try? await SwiftCodeSDK.GitService.shared.unstage(path: URL(fileURLWithPath: file.path), repositoryURL: url)
        }
        await refreshStatus()
    }

    public func discardChanges(_ file: GitFileStatus) async {
        guard let url = repositoryURL else { return }
        if usesSpaces {
            try? await SpacesService.shared.discardChanges(path: URL(fileURLWithPath: file.path), repositoryURL: url)
        } else {
            try? await SwiftCodeSDK.GitService.shared.discardChanges(path: URL(fileURLWithPath: file.path), repositoryURL: url)
        }
        await refreshStatus()
    }

    public func commit(message: String) async {
        guard let url = repositoryURL else { return }
        if usesSpaces {
            try? await SpacesService.shared.commit(message: message, repositoryURL: url)
        } else {
            try? await SwiftCodeSDK.GitService.shared.commit(message: message, repositoryURL: url)
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
                    try await SwiftCodeSDK.GitService.shared.createBranch(name: name, repositoryURL: url)
                }
                await refreshStatus()
            } catch {
                lastError = error.localizedDescription
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
                    try await SwiftCodeSDK.GitService.shared.checkout(branch: branch.name, repositoryURL: url)
                }
                await refreshStatus()
            } catch {
                lastError = error.localizedDescription
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
                    try await SwiftCodeSDK.GitService.shared.deleteBranch(name: branch.name, repositoryURL: url)
                }
                await refreshStatus()
            } catch {
                lastError = error.localizedDescription
                LoggingTool.error("Branch deletion failed: \(error)")
            }
        }
    }

    public func getDiff() async -> [GitDiffHunk] {
        guard let url = repositoryURL else { return [] }
        if usesSpaces {
            return (try? await SpacesService.shared.getDiff(repositoryURL: url)) ?? []
        }
        return (try? await SwiftCodeSDK.GitService.shared.getDiff(repositoryURL: url)) ?? []
    }

    public func rollback(to sha: String) async throws {
        guard let url = repositoryURL else { return }
        try beginOperation("rollback")
        defer { endOperation() }
        do {
            if usesSpaces {
                try await SpacesService.shared.rollback(to: sha, repositoryURL: url)
            } else {
                try await SwiftCodeSDK.GitService.shared.rollback(to: sha, repositoryURL: url)
            }
        } catch {
            lastError = error.localizedDescription
            throw error
        }
        await refreshStatus()
    }

    public func forcePush(branch: String) async throws {
        guard let url = repositoryURL else { return }
        try beginOperation("force push")
        defer { endOperation() }
        do {
            if usesSpaces {
                try await SpacesService.shared.forcePush(branch: branch, repositoryURL: url)
            } else {
                try await SwiftCodeSDK.GitService.shared.forcePush(branch: branch, repositoryURL: url)
            }
        } catch {
            lastError = error.localizedDescription
            throw error
        }
        await refreshStatus()
    }

    public func push() async throws {
        guard let url = repositoryURL else { return }
        try beginOperation("push")
        defer { endOperation() }
        do {
            if usesSpaces {
                try await SpacesService.shared.push(repositoryURL: url)
            } else {
                try await SwiftCodeSDK.GitService.shared.push(repositoryURL: url)
            }
        } catch {
            lastError = error.localizedDescription
            throw error
        }
        await refreshStatus()
    }

    public func fetch() async throws {
        guard let url = repositoryURL else { return }
        try beginOperation("fetch")
        defer { endOperation() }
        do {
            if usesSpaces {
                try await SpacesService.shared.fetch(repositoryURL: url)
            } else {
                _ = try await runGit(["fetch"], workingDirectory: url)
            }
        } catch {
            lastError = error.localizedDescription
            throw error
        }
        await refreshStatus()
    }

    public func pull() async throws {
        guard let url = repositoryURL else { return }
        try beginOperation("pull")
        defer { endOperation() }
        do {
            if usesSpaces {
                try await SpacesService.shared.pull(repositoryURL: url)
            } else {
                _ = try await runGit(["pull"], workingDirectory: url)
            }
        } catch {
            lastError = error.localizedDescription
            throw error
        }
        await refreshStatus()
    }

    public func merge(branch: String) async throws {
        guard let url = repositoryURL else { return }
        try beginOperation("merge")
        defer { endOperation() }
        do {
            if usesSpaces {
                try await SpacesService.shared.merge(branch, repositoryURL: url)
            } else {
                _ = try await runGit(["merge", branch], workingDirectory: url)
            }
        } catch {
            lastError = error.localizedDescription
            throw error
        }
        await refreshStatus()
    }

    public func stash(message: String) async throws {
        guard let url = repositoryURL else { return }
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw GitError.commandFailed(command: "stash", exitCode: 1, output: "A stash message is required.")
        }
        try beginOperation("stash")
        defer { endOperation() }
        do {
            if usesSpaces {
                try await SpacesService.shared.stash(message: text, repositoryURL: url)
            } else {
                _ = try await runGit(["stash", "push", "-m", text], workingDirectory: url)
            }
        } catch {
            lastError = error.localizedDescription
            throw error
        }
        await refreshStatus()
    }

    public func rebase(onto: String) async throws {
        guard let url = repositoryURL else { return }
        try beginOperation("rebase")
        defer { endOperation() }
        do {
            if usesSpaces {
                try await SpacesService.shared.rebase(onto: onto, repositoryURL: url)
            } else {
                _ = try await runGit(["rebase", onto], workingDirectory: url)
            }
        } catch {
            lastError = error.localizedDescription
            throw error
        }
        await refreshStatus()
    }

    public func abortMerge() async throws {
        guard let url = repositoryURL else { return }
        try beginOperation("abort merge")
        defer { endOperation() }
        do {
            if usesSpaces {
                try await SpacesService.shared.mergeAbort(repositoryURL: url)
            } else {
                _ = try await runGit(["merge", "--abort"], workingDirectory: url)
            }
        } catch {
            lastError = error.localizedDescription
            throw error
        }
        await refreshStatus()
    }

    public func continueMerge() async throws {
        guard let url = repositoryURL else { return }
        try beginOperation("continue merge")
        defer { endOperation() }
        do {
            if usesSpaces {
                try await SpacesService.shared.mergeContinue(repositoryURL: url)
            } else {
                _ = try await runGit(["merge", "--continue"], workingDirectory: url)
            }
        } catch {
            lastError = error.localizedDescription
            throw error
        }
        await refreshStatus()
    }
}
