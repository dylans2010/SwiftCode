import SwiftUI

struct CodexUndoRedoView: View {
    @StateObject private var workspace = CodexWorkspaceStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Undo / Redo", systemImage: "arrow.uturn.backward.circle")
                .font(.headline)

            HStack(spacing: 12) {
                actionButton(title: "Undo Prompt", systemImage: "arrow.uturn.backward", enabled: !workspace.promptUndoStack.isEmpty) { workspace.undoPrompt() }
                actionButton(title: "Redo Prompt", systemImage: "arrow.uturn.forward", enabled: !workspace.promptRedoStack.isEmpty) { workspace.redoPrompt() }
                actionButton(title: "Undo Output", systemImage: "doc.badge.arrow.up", enabled: !workspace.codeUndoStack.isEmpty) { workspace.undoCode() }
                actionButton(title: "Redo Output", systemImage: "doc.badge.arrow.down", enabled: !workspace.codeRedoStack.isEmpty) { workspace.redoCode() }
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func actionButton(title: String, systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(!enabled)
    }
}
