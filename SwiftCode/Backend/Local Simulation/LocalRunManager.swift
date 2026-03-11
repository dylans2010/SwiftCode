import Foundation
import Combine

/// Controls the run and stop process when users launch the local simulation preview.
/// Analyzes the currently opened project, starts the preview engine, streams simulated
/// build logs, and manages the preview session lifecycle.
@MainActor
final class LocalRunManager: ObservableObject {
    static let shared = LocalRunManager()

    /// `true` while the preview session is active (both building and ready states).
    @Published var isRunning = false
    /// `true` only while the preview is being built; `false` once the container is ready or on error.
    @Published var isPreparing = false
    @Published var buildLogs: [String] = []
    @Published var runtimeContainer: SwiftUIRuntimeLoader.RuntimeContainer?
    @Published var errorMessage: String?

    private let analyzer = ProjectAnalyzer()
    private let engine = PreviewEngine()
    private let loader = SwiftUIRuntimeLoader()

    private init() {}

    /// Starts the local simulation for the given project directory.
    func startPreview(projectDirectory: URL) {
        guard !isRunning else { return }
        isRunning = true
        isPreparing = true
        buildLogs = []
        errorMessage = nil
        runtimeContainer = nil

        Task {
            do {
                appendLog("Analyzing project...")
                let result = analyzer.analyze(projectDirectory: projectDirectory)

                let context = try await engine.prepare(
                    analysisResult: result,
                    projectDirectory: projectDirectory,
                    logHandler: { [weak self] message in
                        Task { @MainActor in
                            self?.appendLog(message)
                        }
                    }
                )

                let container = loader.load(from: context)
                runtimeContainer = container
                isPreparing = false
                appendLog("Preview ready.")
            } catch {
                errorMessage = error.localizedDescription
                appendLog("Error: \(error.localizedDescription)")
                isPreparing = false
                isRunning = false
            }
        }
    }

    /// Stops the running simulation and clears the preview state.
    func stopPreview() {
        isRunning = false
        isPreparing = false
        runtimeContainer = nil
        buildLogs = []
        errorMessage = nil
    }

    private func appendLog(_ message: String) {
        buildLogs.append(message)
    }
}
