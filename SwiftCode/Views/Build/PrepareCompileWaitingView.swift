import SwiftUI

struct PrepareCompileWaitingView: View {
    let project: Project
    @Environment(\.dismiss) private var dismiss
    @State private var isPreparing = true

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.10, green: 0.10, blue: 0.14).ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    if isPreparing {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(1.5)
                            .tint(.blue)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.green)
                    }

                    VStack(spacing: 8) {
                        Text("Preparing For Completion")
                            .font(.title2.bold())
                            .foregroundStyle(.primary)

                        Text("SwiftCode is currently preparing your app so you can build it, please wait…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    Spacer()
                }
            }
            .navigationTitle("Prepare Compiling")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .disabled(isPreparing)
                }
            }
        }
        .task {
            await prepare()
        }
    }

    // MARK: - Preparation

    private func prepare() async {
        isPreparing = true

        // Start the preparation process
        await ProjectBuilderManager.shared.prepareXcodeFiles(for: project)

        // Verify project generation is complete before dismissing.
        let projectDir = await project.directoryURL
        let projectName = project.name

        while !ProjectBuilderManager.shared.hasBuildArtifacts(in: projectDir, projectName: projectName) {
            try? await Task.sleep(for: .seconds(0.5))
            await ProjectBuilderManager.shared.prepareXcodeFiles(for: project)
        }

        isPreparing = false
        // The waiting view must only close after both files are successfully detected in the project directory.
        try? await Task.sleep(for: .seconds(0.5))
        dismiss()
    }
}
