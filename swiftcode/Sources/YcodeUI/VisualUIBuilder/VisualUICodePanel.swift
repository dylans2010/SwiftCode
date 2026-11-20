import SwiftUI

public struct VisualUICodePanel: View {
    let document: VisualUIDocument

    @State private var showingCopiedLabel = false
    @State private var editableDraft = ""
    @State private var editingSource = false

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("LIVE GENERATED CODE (\(document.scene.currentFramework.rawValue))")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Spacer()

                Toggle("Edit & Sync", isOn: $editingSource)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                    .onChange(of: editingSource) { _, on in
                        if on { editableDraft = generatedCode }
                    }

                if editingSource {
                    Button("Apply to Canvas") {
                        if let artboard = document.scene.artboards.first(where: { $0.id == document.scene.activeArtboardID })
                            ?? document.scene.artboards.first {
                            document.checkpoint()
                            VisualUICodeGenerator.applySwiftUISource(editableDraft, to: artboard)
                            editingSource = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                }

                Button {
                    copyCodeToClipboard()
                } label: {
                    Label(showingCopiedLabel ? "Copied" : "Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.plain)
                .font(.caption)
            }
            .padding(8)
            .liquidGlass(style: .subtle, cornerRadius: 0)

            Divider()

            if editingSource {
                TextEditor(text: $editableDraft)
                    .font(.system(.caption, design: .monospaced))
                    .padding(6)
            } else {
                ScrollView {
                    Text(generatedCode)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color.secondary.opacity(0.01))
            }
        }
    }

    private var generatedCode: String {
        VisualUICodeGenerator.generate(document: document)
    }

    private func copyCodeToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(generatedCode, forType: .string)

        withAnimation {
            showingCopiedLabel = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            showingCopiedLabel = false
        }
        VisualUISettings.shared.addLog("Copied source code from side Code panel.")
    }
}
