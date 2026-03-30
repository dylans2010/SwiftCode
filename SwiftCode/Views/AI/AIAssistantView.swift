import SwiftUI

struct AIAssistantView: View {
    enum AssistMode: String, CaseIterable { case chat = "Chat", edit = "Edit", agent = "Agent" }

    @EnvironmentObject private var projectManager: ProjectManager
    @StateObject private var controller = ChatController.shared
    @State private var showHistory = false
    @State private var prompt = ""
    @State private var mode: AssistMode = .chat
    @State private var plan: [String] = []
    @State private var diffPreview = ""
    @State private var sessionMemory: [String] = []

    var body: some View {
        NavigationSplitView {
            List {
                Section("SwiftCode Assist") {
                    Picker("Mode", selection: $mode) {
                        ForEach(AssistMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Context Files") {
                    ForEach(projectManager.openFileTabs) { file in
                        Text(file.path)
                    }
                }
                Section("History") {
                    ForEach(sessionMemory.indices, id: \.self) { i in Text(sessionMemory[i]).font(.caption) }
                }
            }
            .navigationTitle("Assist")
        } detail: {
            VStack(spacing: 10) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(controller.messages) { ChatMessageBubble(message: $0) }
                    }
                }

                GroupBox("Plan → Preview → Apply") {
                    VStack(alignment: .leading) {
                        if plan.isEmpty { Text("Generate a plan to begin.").foregroundStyle(.secondary) }
                        ForEach(plan, id: \.self) { Text("• \($0)") }
                        if !diffPreview.isEmpty {
                            Text(diffPreview).font(.caption.monospaced())
                        }
                    }
                }

                HStack {
                    TextField("Ask SwiftCode Assist", text: $prompt)
                        .textFieldStyle(.roundedBorder)
                    Button("Plan") { generatePlan() }
                    Button("Preview") { previewDiff() }
                    Button("Apply") { applyChanges() }
                    Button("Reject") { plan.removeAll(); diffPreview = "" }
                }
            }
            .padding()
            .navigationTitle("SwiftCode Assist")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showHistory = true } label: { Label("History", systemImage: "clock.arrow.circlepath") }
                }
            }
            .sheet(isPresented: $showHistory) {
                NavigationStack { List(controller.messages) { ChatMessageBubble(message: $0) } }
            }
        }
    }

    private func generatePlan() {
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        plan = [
            "Analyze open files for request: \(text)",
            "Prepare file-level edits with line references",
            "Generate diff preview and await confirmation"
        ]
        sessionMemory.insert("[\(Date().formatted(date: .omitted, time: .shortened))] PLAN: \(text)", at: 0)
    }

    private func previewDiff() {
        diffPreview = "--- before\n+++ after\n@@\n- old code\n+ refactored code for \(mode.rawValue.lowercased()) mode"
    }

    private func applyChanges() {
        sessionMemory.insert("Applied preview at \(Date().formatted(date: .omitted, time: .shortened))", at: 0)
        prompt = ""
    }
}
