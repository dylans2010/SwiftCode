import SwiftUI

struct TestToolsView: View {
    @EnvironmentObject private var projectManager: ProjectManager
    @StateObject private var testManager = TestToolsManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.08, green: 0.08, blue: 0.12).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header Actions
                    HStack(spacing: 16) {
                        Button {
                            if let project = projectManager.activeProject {
                                Task { await testManager.runTests(forProject: project) }
                            }
                        } label: {
                            Label("Run Project Tests", systemImage: "play.fill")
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.orange, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .disabled(testManager.isRunning)

                        Button {
                            if let project = projectManager.activeProject,
                               let file = projectManager.activeFileNode {
                                Task { await testManager.runTests(forFile: file.path, in: project) }
                            }
                        } label: {
                            Label("Test Active File", systemImage: "doc.text.fill")
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.blue, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .disabled(testManager.isRunning || projectManager.activeFileNode == nil)

                        Spacer()
                    }
                    .padding()

                    Divider().opacity(0.3)

                    if testManager.isRunning {
                        ProgressView("Running Tests...")
                            .padding()
                    }

                    // Results List
                    List {
                        ForEach(testManager.results) { result in
                            TestResultRow(result: result)
                                .listRowBackground(Color.white.opacity(0.05))
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Developer Test Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct TestResultRow: View {
    let result: TestResult

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: iconName(for: result.status))
                    .foregroundStyle(iconColor(for: result.status))

                Text(result.name)
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Text(String(format: "%.2f ms", result.executionTime * 1000))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let error = result.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.leading, 24)
            }
        }
        .padding(.vertical, 4)
    }

    private func iconName(for status: TestStatus) -> String {
        switch status {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .failed:  return "xmark.circle.fill"
        }
    }

    private func iconColor(for status: TestStatus) -> Color {
        switch status {
        case .success: return .green
        case .warning: return .orange
        case .failed:  return .red
        }
    }
}

#Preview {
    TestToolsView()
        .environmentObject(ProjectManager.shared)
}
