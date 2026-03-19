import SwiftUI

struct CodexAPIKeyView: View {
    @State private var apiKey: String = KeychainService.shared.get(forKey: KeychainService.codexUserAPIKey) ?? ""
    @State private var isSecured = true
    @State private var isValidating = false
    @State private var validationMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("OpenAI API Key", systemImage: "key.fill")
                    .font(.headline)
                Spacer()
                Button(isSecured ? "Show" : "Hide") {
                    isSecured.toggle()
                }
                .font(.caption)
            }

            Group {
                if isSecured {
                    SecureField("sk-...", text: $apiKey)
                } else {
                    TextField("sk-...", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .textFieldStyle(.roundedBorder)

            HStack {
                Button("Save Key") {
                    let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty {
                        KeychainService.shared.delete(forKey: KeychainService.codexUserAPIKey)
                    } else {
                        KeychainService.shared.set(trimmed, forKey: KeychainService.codexUserAPIKey)
                    }
                    CodexManager.shared.refreshUsageMode()
                    validationMessage = trimmed.isEmpty ? "User key removed. Restricted app-controlled mode will be used if an app key exists." : "User key stored securely in Keychain."
                }
                .buttonStyle(.borderedProminent)

                Button("Validate") {
                    Task {
                        isValidating = true
                        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        let isValid = await CodexManager.shared.validateUserAPIKey(trimmed)
                        validationMessage = isValid ? "Key validated successfully." : "Key validation failed. Check that the key is active and has Codex access."
                        isValidating = false
                    }
                }
                .buttonStyle(.bordered)
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isValidating)
            }

            if !validationMessage.isEmpty {
                Label(validationMessage, systemImage: validationMessage.contains("failed") ? "xmark.octagon.fill" : "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(validationMessage.contains("failed") ? .red : .green)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
