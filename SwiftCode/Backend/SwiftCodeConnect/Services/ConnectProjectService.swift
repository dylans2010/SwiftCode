import Foundation
import Combine

@MainActor
public final class ConnectProjectService: ObservableObject {
    public static let shared = ConnectProjectService()

    @Published public private(set) var remoteProjectState: RemoteProjectStatePayload?
    @Published public private(set) var availableProjects: [ConnectProjectInfo] = []
    @Published public private(set) var activeGitStatus: ConnectGitStatusResponsePayload?
    @Published public private(set) var isLoading = false

    private var cancellables = Set<AnyCancellable>()

    private init() {
        NotificationCenter.default.publisher(for: .connectEnvelopeReceived)
            .compactMap { $0.object as? MessageEnvelope }
            .sink { [weak self] envelope in
                Task { @MainActor [weak self] in
                    self?.handleEnvelope(envelope)
                }
            }
            .store(in: &cancellables)
    }

    public func fetchProjectState() async throws {
        isLoading = true
        defer { isLoading = false }

        let envelope = try MessageEnvelope.encode(
            payload: ["request": "active_project"],
            type: .projectRequest
        )
        try await ConnectConnectionManager.shared.sendEnvelope(envelope)

        let gitEnv = try MessageEnvelope.encode(
            payload: ["request": "git_status"],
            type: .gitStatusRequest
        )
        try await ConnectConnectionManager.shared.sendEnvelope(gitEnv)
    }

    private func handleEnvelope(_ envelope: MessageEnvelope) {
        switch envelope.type {
        case .projectResponse:
            if let response = try? envelope.decodePayload(ConnectProjectResponsePayload.self) {
                self.availableProjects = response.availableProjects
                if let active = response.activeProject {
                    let gitBranch = activeGitStatus?.branch ?? "main"
                    let isDirty = !(activeGitStatus?.isClean ?? true)
                    let ahead = activeGitStatus?.ahead ?? 0
                    let behind = activeGitStatus?.behind ?? 0

                    self.remoteProjectState = RemoteProjectStatePayload(
                        projectName: active.name,
                        projectPath: active.path,
                        activeScheme: active.activeScheme ?? "Default",
                        activeTarget: active.activeTarget ?? "Default",
                        activeBranch: gitBranch,
                        isGitDirty: isDirty,
                        aheadCount: ahead,
                        behindCount: behind,
                        totalFileCount: active.destinations.count
                    )
                }
            } else if let directState = try? envelope.decodePayload(RemoteProjectStatePayload.self) {
                self.remoteProjectState = directState
            }

        case .gitStatusResponse:
            if let gitStatus = try? envelope.decodePayload(ConnectGitStatusResponsePayload.self) {
                self.activeGitStatus = gitStatus
                if let current = self.remoteProjectState {
                    self.remoteProjectState = RemoteProjectStatePayload(
                        projectName: current.projectName,
                        projectPath: current.projectPath,
                        activeScheme: current.activeScheme,
                        activeTarget: current.activeTarget,
                        activeBranch: gitStatus.branch,
                        isGitDirty: !gitStatus.isClean,
                        aheadCount: gitStatus.ahead,
                        behindCount: gitStatus.behind,
                        totalFileCount: current.totalFileCount
                    )
                }
            }

        default:
            break
        }
    }
}
