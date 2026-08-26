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
            .compactMap { $0.object as? ConnectMessageEnvelope }
            .sink { [weak self] envelope in
                Task { @MainActor [weak self] in
                    self?.handleEnvelope(envelope)
                }
            }
            .store(in: &cancellables)
    }

    public func requestBuild(projectPath: String, scheme: String, configuration: String = "Debug", clean: Bool = false) async throws {
        diagnostics.removeAll()
        let payload = RemoteBuildRequestPayload(
            projectPath: projectPath,
            scheme: scheme,
            configuration: configuration,
            cleanBuild: clean
        )
        let envelope = try ConnectMessageEnvelope.makeEnvelope(type: .buildStart, payload: payload)
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
        guard let build = activeBuild else { return }
        let envelope = try ConnectMessageEnvelope.makeEnvelope(type: .buildCancel, payload: ["buildID": build.buildID.uuidString])
        try await ConnectConnectionManager.shared.sendEnvelope(envelope)
        activeBuild = RemoteBuildProgressPayload(
            buildID: build.buildID,
            state: .cancelled,
            progressFraction: build.progressFraction,
            currentTaskName: "Build cancelled by user.",
            elapsedTimeSeconds: build.elapsedTimeSeconds,
            errorCount: build.errorCount,
            warningCount: build.warningCount
        )
    }

    private func handleEnvelope(_ envelope: ConnectMessageEnvelope) {
        switch envelope.type {
        case .buildProgress, .buildCompleted:
            if let progress = try? envelope.decodePayload(RemoteBuildProgressPayload.self) {
                self.activeBuild = progress
            }
        case .buildDiagnostic:
            if let diagnostic = try? envelope.decodePayload(RemoteBuildDiagnosticPayload.self) {
                self.diagnostics.append(diagnostic)
            }
        default:
            break
        }
    }
}
