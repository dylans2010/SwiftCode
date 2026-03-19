import SwiftUI

struct AgentModeView: View {
    @ObservedObject private var agentManager = AgentManager.shared
    @State private var taskInput = ""

    var body: some View {
        VStack(spacing: 18) {
            taskComposer

            if !agentManager.executionState.taskDescription.isEmpty {
                VStack(spacing: 18) {
                    AgentTaskPanel(state: agentManager.executionState)
                    AgentPlanView(plan: agentManager.executionState.plan, currentIndex: agentManager.executionState.currentStepIndex)
                    ToolExecutionView()
                    CodeChangesView()
                    CodeReviewView()
                        .frame(minHeight: 400)
                    AgentConsoleView()
                        .frame(minHeight: 300)
                }
            } else {
                ContentUnavailableView(
                    "No Active Task",
                    systemImage: "bolt.shield",
                    description: Text("Describe a task and the assistant will build a plan, inspect context, and prepare code changes.")
                )
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
                .assistantGlassCard()
            }
        }
    }

    private var taskComposer: some View {
        VStack(alignment: .leading, spacing: 14) {
            AssistantSectionHeader(
                eyebrow: "Agent mode",
                title: "Launch a tool-driven task",
                subtitle: "Create a task for the assistant to inspect files, draft edits, and report progress clearly."
            )

            HStack(alignment: .bottom, spacing: 12) {
                TextField("Describe the task you want the agent to perform", text: $taskInput, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .padding(16)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .foregroundStyle(.white)

                Button {
                    executeTask()
                } label: {
                    Label("Run", systemImage: "play.fill")
                }
                .buttonStyle(AssistantPrimaryButtonStyle())
                .frame(maxWidth: 150)
                .disabled(taskInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || agentManager.executionState.status == .running)
            }
        }
        .padding(20)
        .assistantGlassCard()
    }

    private func executeTask() {
        let task = taskInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !task.isEmpty else { return }
        taskInput = ""

        Task {
            let request = PluginAgentRequest(
                task: task,
                projectPath: ProjectManager.shared.activeProject?.directoryURL.path ?? "",
                pluginIdentifier: "com.swiftcode.main",
                contextFiles: ProjectManager.shared.activeFileNode != nil ? [ProjectManager.shared.activeProject!.directoryURL.appendingPathComponent(ProjectManager.shared.activeFileNode!.path).path] : [],
                allowedTools: ["read_file", "list_files", "write_file"]
            )

            _ = try? await agentManager.processTask(request)
        }
    }
}
