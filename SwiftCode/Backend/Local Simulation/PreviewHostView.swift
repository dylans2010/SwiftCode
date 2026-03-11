import SwiftUI

/// Visual container that renders the app UI preview inside a safe runtime wrapper.
/// Wraps the root view content so that any issues do not affect the main SwiftCode interface.
struct PreviewHostView: View {
    @StateObject private var runManager = LocalRunManager.shared
    @EnvironmentObject private var projectManager: ProjectManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(red: 0.10, green: 0.10, blue: 0.14).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header bar
                previewHeader

                Divider().opacity(0.3)

                // Content area
                if runManager.isPreparing {
                    buildProgressView
                } else if let container = runManager.runtimeContainer {
                    previewContentView(container: container)
                } else if let error = runManager.errorMessage {
                    errorView(message: error)
                } else {
                    idleView
                }
            }
        }
        .onAppear {
            startSimulation()
        }
        .onDisappear {
            runManager.stopPreview()
        }
    }

    // MARK: - Header

    private var previewHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Local Simulation")
                    .font(.headline)
                    .foregroundStyle(.white)
                if let container = runManager.runtimeContainer {
                    Text(container.projectName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                runManager.stopPreview()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .imageScale(.large)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(red: 0.12, green: 0.12, blue: 0.16))
    }

    // MARK: - Build Progress

    private var buildProgressView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.orange)
                .scaleEffect(1.5)
                .padding(.top, 40)

            Text("Building Preview...")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            buildLogsSection
                .frame(maxHeight: 200)

            Spacer()
        }
        .padding()
    }

    private var buildLogsSection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(runManager.buildLogs.enumerated()), id: \.offset) { index, log in
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.right")
                                .imageScale(.small)
                                .foregroundStyle(.orange)
                            Text(log)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.white)
                        }
                        .id(index)
                    }
                }
                .padding(8)
            }
            .background(Color(red: 0.08, green: 0.08, blue: 0.12))
            .cornerRadius(8)
            .onChange(of: runManager.buildLogs.count) { _, _ in
                if let last = runManager.buildLogs.indices.last {
                    withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                }
            }
        }
    }

    // MARK: - Preview Content

    private func previewContentView(container: SwiftUIRuntimeLoader.RuntimeContainer) -> some View {
        VStack(spacing: 0) {
            // Device frame simulation
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "app.fill")
                        .foregroundStyle(.orange)
                    Text(container.rootViewName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("iOS Simulator")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(red: 0.14, green: 0.14, blue: 0.18))

                Divider().opacity(0.3)

                // Rendered preview area
                safePreviewContainer(container: container)
            }
            .background(Color(red: 0.08, green: 0.08, blue: 0.12))
            .cornerRadius(12)
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Build logs (collapsed at bottom)
            if !runManager.buildLogs.isEmpty {
                buildLogsSection
                    .frame(height: 80)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
        }
    }

    private func safePreviewContainer(container: SwiftUIRuntimeLoader.RuntimeContainer) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer(minLength: 40)

                Image(systemName: "swift")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundStyle(.orange)

                Text(container.rootViewName)
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.white)

                Text(container.projectName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let source = container.rootViewSource {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview Source")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(source)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(Color(red: 0.10, green: 0.10, blue: 0.14))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                } else {
                    Text("SwiftUI preview is running inside the safe container.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer(minLength: 40)
            }
        }
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .imageScale(.large)
                .foregroundStyle(.red)
                .font(.largeTitle)

            Text("Preview Failed")
                .font(.headline)
                .foregroundStyle(.white)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                startSimulation()
            } label: {
                Text("Retry")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)
            Spacer()
        }
    }

    // MARK: - Idle View

    private var idleView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "play.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.orange)
            Text("Starting simulation...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Actions

    private func startSimulation() {
        guard let project = projectManager.activeProject else {
            runManager.errorMessage = "No project is currently open."
            return
        }
        runManager.startPreview(projectDirectory: project.directoryURL)
    }
}
