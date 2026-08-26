import Foundation
import Combine

@MainActor
public final class ConnectBuildService: ObservableObject {
    public static let shared = ConnectBuildService()

    @Published public private(set) var activeBuild: RemoteBuildProgressPayload?
    @Published public private(set) var diagnostics: [RemoteBuildDiagnosticPayload] = []

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

    public func requestBuild(projectPath: String, scheme: String, configuration: String = "Debug", clean: Bool = false) async throws {
        diagnostics.removeAll()
        let payload = ConnectBuildRequestPayload(
            scheme: scheme,
            configuration: configuration
        )
        let envelope = try MessageEnvelope.encode(payload: payload, type: .buildRequest)
        try await ConnectConnectionManager.shared.sendEnvelope(envelope)

        activeBuild = RemoteBuildProgressPayload(
            buildID: UUID(),
            state: .preparing,
            progressFraction: 0.05,
            currentTaskName: "Preparing build environment on Mac...",
            elapsedTimeSeconds: 0,
            errorCount: 0,
            warningCount: 0
        )
    }

    public func cancelBuild() async throws {
        let envelope = try MessageEnvelope.encode(payload: ["action": "cancel"], type: .cancelBuildRequest)
        try await ConnectConnectionManager.shared.sendEnvelope(envelope)
        if let current = activeBuild {
            activeBuild = RemoteBuildProgressPayload(
                buildID: current.buildID,
                state: .cancelled,
                progressFraction: current.progressFraction,
                currentTaskName: "Build cancelled by user.",
                elapsedTimeSeconds: current.elapsedTimeSeconds,
                errorCount: current.errorCount,
                warningCount: current.warningCount
            )
        }
    }

    private func handleEnvelope(_ envelope: MessageEnvelope) {
        switch envelope.type {
        case .buildStarted:
            self.diagnostics.removeAll()
            self.activeBuild = RemoteBuildProgressPayload(
                buildID: UUID(),
                state: .building,
                progressFraction: 0.1,
                currentTaskName: "Compilation initiated...",
                elapsedTimeSeconds: 0,
                errorCount: 0,
                warningCount: 0
            )

        case .buildProgress:
            if let progress = try? envelope.decodePayload(ConnectBuildProgressPayload.self) {
                let fraction = progress.totalSteps > 0 ? Double(progress.completedSteps) / Double(progress.totalSteps) : 0.5
                self.activeBuild = RemoteBuildProgressPayload(
                    buildID: self.activeBuild?.buildID ?? UUID(),
                    state: .building,
                    progressFraction: fraction,
                    currentTaskName: progress.message,
                    elapsedTimeSeconds: (self.activeBuild?.elapsedTimeSeconds ?? 0) + 1.0,
                    errorCount: self.activeBuild?.errorCount ?? 0,
                    warningCount: self.activeBuild?.warningCount ?? 0
                )
            } else if let remoteProgress = try? envelope.decodePayload(RemoteBuildProgressPayload.self) {
                self.activeBuild = remoteProgress
            }

        case .buildDiagnostic:
            if let diag = try? envelope.decodePayload(ConnectBuildDiagnosticPayload.self) {
                let severity: DiagnosticSeverity = diag.severity == "error" ? .error : (diag.severity == "warning" ? .warning : .note)
                let item = RemoteBuildDiagnosticPayload(
                    severity: severity,
                    message: diag.message,
                    filePath: diag.file,
                    line: diag.line,
                    column: diag.column
                )
                self.diagnostics.append(item)
            } else if let remoteDiag = try? envelope.decodePayload(RemoteBuildDiagnosticPayload.self) {
                self.diagnostics.append(remoteDiag)
            }

        case .buildCompleted:
            if let completed = try? envelope.decodePayload(ConnectBuildCompletedPayload.self) {
                self.activeBuild = RemoteBuildProgressPayload(
                    buildID: self.activeBuild?.buildID ?? UUID(),
                    state: completed.success ? .succeeded : .failed,
                    progressFraction: 1.0,
                    currentTaskName: completed.success ? "Build succeeded." : "Build failed.",
                    elapsedTimeSeconds: completed.duration,
                    errorCount: completed.errorCount,
                    warningCount: completed.warningCount
                )
            }

        default:
            break
        }
    }
}
