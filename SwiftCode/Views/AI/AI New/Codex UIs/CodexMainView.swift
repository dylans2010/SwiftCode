import SwiftUI

struct CodexMainView: View {
    @ObservedObject private var manager = CodexManager.shared
    @State private var prompt = ""
    @State private var renderedOutput = ""
    @State private var localError = ""

    var body: some View {
        VStack(spacing: 16) {
            CodexAPIKeyView()
            CodexUsageView()

            if let message = activeErrorMessage {
                CodexErrorView(message: message)
            }

            VStack(alignment: .leading, spacing: 10) {
                Label("Prompt", systemImage: "square.and.pencil")
                    .font(.headline)

                TextEditor(text: $prompt)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                HStack {
                    Button("Reset Session") {
                        manager.resetSession()
                        renderedOutput = ""
                        localError = ""
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    if manager.isRequestInFlight {
                        Button("Cancel") {
                            manager.cancelRequest()
                        }
                        .buttonStyle(.bordered)
                    }

                    Button("Send") {
                        Task { await sendPrompt() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || manager.isRequestInFlight || !manager.hasValidConfiguration)
                }
            }
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                Label("Response", systemImage: "text.bubble")
                    .font(.headline)
                ScrollView {
                    Text(renderedOutput.isEmpty ? manager.activeSession.lastResponse.ifEmpty("Codex responses will appear here.") : renderedOutput)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: .infinity)
            }
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding()
        .animation(.easeInOut(duration: 0.2), value: manager.activeSession.id)
    }

    private var activeErrorMessage: String? {
        let message = localError.isEmpty ? manager.activeSession.lastErrorMessage : localError
        return message?.isEmpty == true ? nil : message
    }

    @MainActor
    private func sendPrompt() async {
        localError = ""
        do {
            _ = try await manager.sendPrompt(prompt)
            manager.streamResponse { streamed in
                renderedOutput = streamed
            }
            prompt = ""
        } catch {
            localError = CodexErrorHandler.userFacingMessage(for: error)
        }
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
