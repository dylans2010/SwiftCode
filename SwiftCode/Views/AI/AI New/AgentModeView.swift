import SwiftUI

struct AgentModeView: View {
    @ObservedObject private var agentManager = AgentManager.shared
    @State private var taskInput: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Task Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Assigned Task")
                        .font(.headline)

                    HStack {
                        TextField("Describe a task for the agent...", text: $taskInput)
                            .textFieldStyle(.roundedBorder)

                        Button {
                            executeTask()
                        } label: {
                            Image(systemName: "play.fill")
                                .padding(8)
                                .background(Color.blue, in: Circle())
                                .foregroundColor(.white)
                        }
                        .disabled(taskInput.isEmpty || agentManager.executionState.status == .running)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

                if !agentManager.executionState.taskDescription.isEmpty {
                    // Modular Panels
                    AgentTaskPanel(state: agentManager.executionState)

                    AgentPlanView(plan: agentManager.executionState.plan, currentIndex: agentManager.executionState.currentStepIndex)

                    ToolExecutionView()

                    CodeChangesView()

                    CodeReviewView()
                        .frame(minHeight: 400) // Integration with existing view

                    AgentConsoleView()
                        .frame(minHeight: 300)
                } else {
                    ContentUnavailableView("No Active Task", systemImage: "bolt.shield", description: Text("Enter a task above to start the agent."))
                        .padding(.top, 40)
                }
            }
            .padding()
        }
    }

    private func executeTask() {
        let task = taskInput
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
