import SwiftUI
import YcodeAssistant
import YcodeIDECore

public struct AssistModernComposerView: View {
    @Binding public var text: String
    @Binding public var attachedFiles: [AgentFileContext]
    public var isProcessing: Bool
    public var currentModelName: String
    public var onSend: () -> Void
    public var onAttach: () -> Void
    public var onVoiceInput: () -> Void
    public var onSelectModel: () -> Void

    @AppStorage("com.swiftcode.assist.reasoningLevel") private var reasoningLevel: String = "Minimal"
    private let reasoningOptions = ["Minimal", "Medium", "High", "Extended"]

    public init(
        text: Binding<String>,
        attachedFiles: Binding<[AgentFileContext]> = .constant([]),
        isProcessing: Bool = false,
        currentModelName: String = "Claude Agent",
        onSend: @escaping () -> Void = {},
        onAttach: @escaping () -> Void = {},
        onVoiceInput: @escaping () -> Void = {},
        onSelectModel: @escaping () -> Void = {}
    ) {
        self._text = text
        self._attachedFiles = attachedFiles
        self.isProcessing = isProcessing
        self.currentModelName = currentModelName
        self.onSend = onSend
        self.onAttach = onAttach
        self.onVoiceInput = onVoiceInput
        self.onSelectModel = onSelectModel
    }

    private var placeholder: String {
        let name = currentModelName.isEmpty ? "SwiftCode Assist" : currentModelName
        return "Message \(name)"
    }

    public var body: some View {
        VStack(spacing: 8) {
            if !attachedFiles.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(attachedFiles) { file in
                            HStack(spacing: 4) {
                                Image(systemName: "doc.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.orange)
                                Text(file.filename)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.primary)
                                Button {
                                    attachedFiles.removeAll { $0.id == file.id }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.primary.opacity(0.08), in: Capsule())
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    Button(action: onAttach) {
                        Image(systemName: "paperclip")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Attach Files (Context)")

                    TextField(placeholder, text: $text, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .lineLimit(1...5)
                        .onSubmit {
                            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                onSend()
                            }
                        }

                    Button(action: onVoiceInput) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Dictation / Voice Input")

                    Button(action: onSend) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary.opacity(0.3) : Color.accentColor)
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
                    .buttonStyle(.plain)
                    .help("Send Message (Return)")
                }

                Divider().opacity(0.3)

                HStack(spacing: 8) {
                    Button(action: onSelectModel) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.accentColor)

                            Text(currentModelName)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.primary)

                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                        .overlay(Capsule().stroke(Color.primary.opacity(0.1), lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                    .help("Select Model Provider")

                    Menu {
                        ForEach(reasoningOptions, id: \.self) { option in
                            Button {
                                reasoningLevel = option
                            } label: {
                                HStack {
                                    Text(option)
                                    if reasoningLevel == option {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("Reasoning: \(reasoningLevel)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)

                            Image(systemName: "chevron.down")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.04), in: Capsule())
                        .overlay(Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 0.8))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("Model Reasoning Effort")

                    Spacer()
                }
            }
            .padding(10)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 2)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }
}
