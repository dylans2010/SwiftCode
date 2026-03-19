import SwiftUI

@MainActor
final class CodexWorkspaceStore: ObservableObject {
    static let shared = CodexWorkspaceStore()

    struct Snapshot: Identifiable, Equatable {
        let id = UUID()
        let prompt: String
        let output: String
        let date: Date
        let label: String
    }

    struct FileRevision: Identifiable, Equatable {
        let id = UUID()
        let fileName: String
        let content: String
        let date: Date
        let source: String
    }

    struct PullRequestComment: Identifiable, Equatable {
        let id = UUID()
        let author: String
        let body: String
        let date: Date
    }

    @Published var prompt = ""
    @Published var renderedOutput = ""
    @Published var previousOutput = ""
    @Published var localError = ""
    @Published var selectedRevisionID: FileRevision.ID?
    @Published var comments: [PullRequestComment] = []
    @Published var prStatus: PRStatus = .pending
    @Published private(set) var outputHistory: [Snapshot] = []
    @Published private(set) var fileHistory: [FileRevision] = []
    @Published private(set) var promptUndoStack: [String] = []
    @Published private(set) var promptRedoStack: [String] = []
    @Published private(set) var codeUndoStack: [String] = []
    @Published private(set) var codeRedoStack: [String] = []

    enum PRStatus: String, CaseIterable {
        case pending = "Pending Review"
        case approved = "Approved"
        case rejected = "Changes Requested"

        var tint: Color {
            switch self {
            case .pending: return .orange
            case .approved: return .green
            case .rejected: return .red
            }
        }
    }

    var selectedRevision: FileRevision? {
        guard let selectedRevisionID else { return fileHistory.last }
        return fileHistory.first(where: { $0.id == selectedRevisionID }) ?? fileHistory.last
    }

    var changedFiles: [String] {
        let names = fileHistory.map(\.fileName)
        return Array(Set(names)).sorted()
    }

    func updatePrompt(_ newValue: String) {
        guard prompt != newValue else { return }
        promptUndoStack.append(prompt)
        if promptUndoStack.count > 50 { promptUndoStack.removeFirst() }
        promptRedoStack.removeAll()
        prompt = newValue
    }

    func setOutput(_ newValue: String, label: String) {
        if !renderedOutput.isEmpty {
            previousOutput = renderedOutput
            codeUndoStack.append(renderedOutput)
            if codeUndoStack.count > 50 { codeUndoStack.removeFirst() }
            codeRedoStack.removeAll()
        }
        renderedOutput = newValue
        outputHistory.insert(Snapshot(prompt: prompt, output: newValue, date: Date(), label: label), at: 0)
        captureRevision(content: newValue, source: label)
    }

    func captureRevision(content: String, source: String) {
        let extractedFiles = Self.extractFiles(from: content)
        if extractedFiles.isEmpty {
            let revision = FileRevision(fileName: "GeneratedOutput.swift", content: content, date: Date(), source: source)
            fileHistory.insert(revision, at: 0)
            selectedRevisionID = revision.id
        } else {
            let revisions = extractedFiles.map { FileRevision(fileName: $0.fileName, content: $0.content, date: Date(), source: source) }
            fileHistory.insert(contentsOf: revisions, at: 0)
            selectedRevisionID = revisions.first?.id
        }
    }

    func undoPrompt() {
        guard let previous = promptUndoStack.popLast() else { return }
        promptRedoStack.append(prompt)
        prompt = previous
    }

    func redoPrompt() {
        guard let next = promptRedoStack.popLast() else { return }
        promptUndoStack.append(prompt)
        prompt = next
    }

    func undoCode() {
        guard let previous = codeUndoStack.popLast() else { return }
        codeRedoStack.append(renderedOutput)
        previousOutput = renderedOutput
        renderedOutput = previous
    }

    func redoCode() {
        guard let next = codeRedoStack.popLast() else { return }
        codeUndoStack.append(renderedOutput)
        previousOutput = renderedOutput
        renderedOutput = next
    }

    func reset() {
        prompt = ""
        renderedOutput = ""
        previousOutput = ""
        localError = ""
        selectedRevisionID = nil
        comments.removeAll()
        prStatus = .pending
        outputHistory.removeAll()
        fileHistory.removeAll()
        promptUndoStack.removeAll()
        promptRedoStack.removeAll()
        codeUndoStack.removeAll()
        codeRedoStack.removeAll()
    }

    func addComment(_ body: String, author: String = "Reviewer") {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        comments.append(PullRequestComment(author: author, body: trimmed, date: Date()))
    }

    private static func extractFiles(from content: String) -> [(fileName: String, content: String)] {
        let pattern = "```(?:[a-zA-Z0-9_+-]+)?\\n([\\s\\S]*?)```"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(content.startIndex..., in: content)
        let matches = regex.matches(in: content, range: range)

        return matches.enumerated().compactMap { index, match in
            guard match.numberOfRanges > 1,
                  let contentRange = Range(match.range(at: 1), in: content) else { return nil }
            let snippet = String(content[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let fileName = Self.detectFileName(in: snippet) ?? "GeneratedFile\(index + 1).swift"
            return (fileName, snippet)
        }
    }

    private static func detectFileName(in snippet: String) -> String? {
        for line in snippet.split(separator: "\n", omittingEmptySubsequences: false).prefix(5) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasSuffix(".swift") { return trimmed.replacingOccurrences(of: "//", with: "").trimmingCharacters(in: .whitespaces) }
        }
        if snippet.contains("import SwiftUI") || snippet.contains("import Foundation") { return "GeneratedFile.swift" }
        return nil
    }
}

struct CodexMainView: View {
    @ObservedObject private var manager = CodexManager.shared
    @StateObject private var workspace = CodexWorkspaceStore.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                CodexAPIKeyView()
                CodexUsageView()

                if let message = activeErrorMessage {
                    CodexErrorView(message: message)
                }

                promptComposer
                CodexUndoRedoView()
                CodexRerunView { Task { await rerunPrompt() } }
                CodexDiffViewer()
                CodexFileHistoryView()
                CodexPullRequestView()
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .animation(.easeInOut(duration: 0.25), value: manager.activeSession.updatedAt)
        .animation(.easeInOut(duration: 0.25), value: workspace.renderedOutput)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Codex Agent Workspace")
                    .font(.title2.weight(.semibold))
                Text("Streaming output, diffs, file history, reruns, and PR review in one place.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Label(manager.isRequestInFlight ? "Streaming" : "Ready", systemImage: manager.isRequestInFlight ? "dot.radiowaves.left.and.right" : "checkmark.circle")
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(manager.isRequestInFlight ? Color.blue.opacity(0.12) : Color.green.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var promptComposer: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Prompt", systemImage: "wand.and.stars")
                    .font(.headline)
                Spacer()
                Button("Reset Session") {
                    manager.resetSession()
                    workspace.reset()
                }
                .buttonStyle(.bordered)
            }

            TextEditor(text: Binding(get: { workspace.prompt }, set: { workspace.updatePrompt($0) }))
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 140)
                .padding(8)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack {
                if manager.isRequestInFlight {
                    Button("Cancel") { manager.cancelRequest() }
                        .buttonStyle(.bordered)
                }

                Spacer()

                Button {
                    Task { await sendPrompt() }
                } label: {
                    Label("Generate", systemImage: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(workspace.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || manager.isRequestInFlight || !manager.hasValidConfiguration)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var activeErrorMessage: String? {
        let message = workspace.localError.isEmpty ? manager.activeSession.lastErrorMessage : workspace.localError
        return message?.isEmpty == true ? nil : message
    }

    private func sendPrompt() async {
        workspace.localError = ""
        do {
            let response = try await manager.sendPrompt(workspace.prompt)
            manager.streamResponse { streamed in
                workspace.renderedOutput = streamed
            }
            workspace.setOutput(response, label: "Generated")
            workspace.prStatus = .pending
        } catch {
            workspace.localError = CodexErrorHandler.userFacingMessage(for: error)
        }
    }

    private func rerunPrompt() async {
        guard !workspace.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        workspace.previousOutput = workspace.renderedOutput
        await sendPrompt()
    }
}
