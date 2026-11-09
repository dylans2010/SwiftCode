import SwiftUI
import SwiftCodeGitHub
import YcodeIDECore

struct CreateGistView: View {
    @Environment(\.dismiss) private var dismiss
    var initialFilename: String?
    var initialContent: String
    var onDismiss: () -> Void

    @State private var description = ""
    @State private var isPublic = false
    @State private var filename: String
    @State private var content: String
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    init(initialFilename: String? = nil, initialContent: String = "", onDismiss: @escaping () -> Void = {}) {
        self.initialFilename = initialFilename
        self.initialContent = initialContent
        self.onDismiss = onDismiss
        _filename = State(initialValue: initialFilename ?? "untitled.swift")
        _content = State(initialValue: initialContent)
    }

    var body: some View {
        NavigationStack {
            Form {
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
                Section("Gist Details") {
                    TextField("Description", text: $description)
                    Toggle("Public Gist", isOn: $isPublic)
                }
                Section("File") {
                    TextField("Filename", text: $filename)
                    TextEditor(text: $content)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 200)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("New Gist")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            isSubmitting = true
                            onDismiss()
                            dismiss()
                        }
                    }
                    .disabled(filename.isEmpty || isSubmitting)
                }
            }
        }
        .frame(minWidth: 480, minHeight: 360)
    }
}
