import AppKit
import Foundation
import SwiftUI

public enum PendingStage: Sendable {
    case notDownloaded
    case downloading
    case readyToInstall
    case installing
}

@MainActor
public final class AppUpdateService: NSObject, ObservableObject {
    public static let shared = AppUpdateService()

    @Published public private(set) var pendingUpdate: AppUpdateInfo?
    @Published public private(set) var pendingStage: PendingStage = .notDownloaded
    @Published public private(set) var phase: AppUpdatePhase = .idle
    @Published public private(set) var releaseNoteBlocks: [ReleaseNoteBlock] = []
    @Published public private(set) var isLoadingReleaseNotes: Bool = false
    @Published public private(set) var downloadProgress: Double?
    @Published public private(set) var downloadStatusText: String?
    @Published public private(set) var lastErrorMessage: String?
    @Published public var startupErrorMessage: String? = nil
    @Published public private(set) var lastCheckDate: Date?
    @Published public private(set) var lastCheckWasUpToDate: Bool = false
    @Published public private(set) var isChecking: Bool = false
    @Published public private(set) var canRetryTermination: Bool = false
    @Published public var automaticallyDownloadsUpdates: Bool = true
    @Published public var automaticallyChecksForUpdates: Bool = true
    @Published public var allowsAutomaticUpdates: Bool = true

    public var installButtonTitle: String {
        pendingStage == .installing ? "Install and Relaunch" : "Install Update"
    }

    public var sessionInProgress: Bool {
        switch phase {
        case .downloading, .extracting, .readyToInstall, .installing:
            return true
        case .idle, .offer, .error:
            return false
        }
    }

    public var publicKeyConfigured: Bool {
        AppUpdateConfiguration.isPublicKeyConfigured
    }

    public override init() {
        super.init()
    }

    public func handleWindowClosed() {
        
    }

    public func bringUpdateWindowToFront() {
        showUpdateWindow()
    }

    public func showUpdateWindow() {
        NotificationCenter.default.post(name: NSNotification.Name("SwiftCodeShowUpdateWindow"), object: nil)
    }

    public func checkForUpdates() {
        guard !isChecking else { return }
        isChecking = true
        lastErrorMessage = nil
        Task {
            do {
                guard let feedURL = AppUpdateConfiguration.feedURL else {
                    lastCheckWasUpToDate = true
                    isChecking = false
                    return
                }
                let (data, _) = try await URLSession.shared.data(from: feedURL)
                
                lastCheckDate = Date()
                lastCheckWasUpToDate = true
                isChecking = false
            } catch {
                lastErrorMessage = error.localizedDescription
                isChecking = false
            }
        }
    }

    public func skipPendingUpdate() {
        pendingUpdate = nil
        phase = .idle
    }

    public func remindPendingUpdateLater() {
        if let update = pendingUpdate {
            var map = RemindLaterGate.loadFromDefaults()
            map[update.versionString] = RemindLaterGate.remindUntil()
            RemindLaterGate.saveToDefaults(map)
        }
        pendingUpdate = nil
        phase = .idle
    }

    public func learnMoreAboutPendingUpdate() {
        if let url = pendingUpdate?.infoURL ?? pendingUpdate?.releaseNotesURL {
            NSWorkspace.shared.open(url)
        }
    }

    public func installPendingUpdate() {
        pendingStage = .installing
        phase = .downloading
    }

    public func cancelDownload() {
        phase = .idle
        pendingStage = .notDownloaded
    }

    public func dismissReadyUpdate() {
        phase = .idle
    }

    public func installReadyUpdate() {
        phase = .installing
    }

    public func retryTerminatingApplication() {
        NSApplication.shared.terminate(nil)
    }

    public func closeUpdateWindow() {
        phase = .idle
    }
}
