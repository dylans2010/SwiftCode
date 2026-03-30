import SwiftUI

struct AssistMainView: View {
    @StateObject private var assistManager = AssistManager.shared
    @EnvironmentObject private var projectManager: ProjectManager
    @State private var promptText = ""
    @FocusState private var isPromptFocused: Bool

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                // Main Chat & Plan Area
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if assistManager.steps.isEmpty && assistManager.currentDrafts.isEmpty {
                                welcomeState
                            } else {
                                ForEach(assistManager.steps) { step in
                                    AssistStepRow(step: step)
                                }

                                if !assistManager.currentDrafts.isEmpty {
                                    AssistDraftSummaryView(drafts: assistManager.currentDrafts)
                                }
                            }
                        }
                        .padding()
                    }

                    Spacer()

                    if !assistManager.currentDrafts.isEmpty {
                        actionToolbar
                    }

                    promptArea
                }
                .frame(maxWidth: .infinity)

                Divider()

                // Sidebar for Context and History
                AssistSidebarView()
                    .frame(width: 250)
            }
            .background(Color(red: 0.05, green: 0.05, blue: 0.07))
            .navigationTitle("SwiftCode Assist")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var welcomeState: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .top, endPoint: .bottom))

            Text("How can I help with your code today?")
                .font(.title2.bold())

            Text("I can refactor logic, fix bugs, or generate new features with full awareness of your project structure.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }

    private var actionToolbar: some View {
        HStack(spacing: 16) {
            Button(role: .destructive) {
                assistManager.rejectChanges()
            } label: {
                Label("Reject", systemImage: "xmark.circle")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1), in: Capsule())
            }

            Spacer()

            Button {
                Task { await assistManager.applyChanges() }
            } label: {
                Label("Apply Changes", systemImage: "checkmark.circle.fill")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue, in: Capsule())
                    .foregroundStyle(.white)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
    }

    private var promptArea: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .bottom, spacing: 12) {
                TextField("Ask Assist to do something...", text: $promptText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .focused($isPromptFocused)

                Button {
                    if let project = projectManager.activeProject {
                        Task {
                            let p = promptText
                            promptText = ""
                            await assistManager.processRequest(p, project: project)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(promptText.isEmpty ? .secondary : .blue)
                }
                .disabled(promptText.isEmpty || assistManager.status != .idle)
            }
            .padding()
        }
        .background(Color(red: 0.08, green: 0.08, blue: 0.1))
    }
}

struct AssistStepRow: View {
    let step: AssistStep

    var body: some View {
        HStack(spacing: 12) {
            statusIcon
            Text(step.description)
                .font(.subheadline)
                .foregroundStyle(step.status == .failed ? .red : .primary)
            Spacer()
        }
        .padding(10)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch step.status {
        case .completed:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
        case .drafting, .verifying, .applying:
            ProgressView().controlSize(.small)
        default:
            Image(systemName: "circle").foregroundStyle(.secondary)
        }
    }
}

struct AssistDraftSummaryView: View {
    let drafts: [AssistDraft]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Proposed Changes (\(drafts.count) files)")
                .font(.headline)

            ForEach(drafts) { draft in
                NavigationLink {
                    AssistDiffView(draft: draft)
                } label: {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundStyle(.blue)
                        Text(draft.filePath)
                            .font(.caption)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.2), lineWidth: 1))
    }
}

struct AssistSidebarView: View {
    @ObservedObject var assistManager = AssistManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Section(header: Text("Context Files").font(.caption.bold()).foregroundStyle(.secondary)) {
                // Mock active files
                VStack(alignment: .leading, spacing: 8) {
                    contextFileRow(name: "ContentView.swift")
                    contextFileRow(name: "ProjectManager.swift")
                }
            }

            Divider()

            Section(header: Text("History").font(.caption.bold()).foregroundStyle(.secondary)) {
                if assistManager.chatHistory.isEmpty {
                    Text("No history yet")
                        .font(.caption2)
                        .italic()
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            VStack(spacing: 8) {
                modeToggle(mode: .chat, icon: "bubble.left.and.bubble.right.fill")
                modeToggle(mode: .edit, icon: "pencil.and.outline")
                modeToggle(mode: .agent, icon: "bolt.fill")
            }
        }
        .padding()
        .background(Color(red: 0.03, green: 0.03, blue: 0.05))
    }

    private func contextFileRow(name: String) -> some View {
        HStack {
            Image(systemName: "doc")
                .font(.caption)
            Text(name)
                .font(.caption2)
            Spacer()
            Image(systemName: "xmark")
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        }
    }

    private func modeToggle(mode: AssistMode, icon: String) -> some View {
        Button {
            assistManager.currentMode = mode
        } label: {
            HStack {
                Image(systemName: icon)
                Text(mode.rawValue.capitalized)
                Spacer()
            }
            .font(.caption.bold())
            .padding(10)
            .background(assistManager.currentMode == mode ? Color.blue : Color.clear)
            .foregroundStyle(assistManager.currentMode == mode ? .white : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
