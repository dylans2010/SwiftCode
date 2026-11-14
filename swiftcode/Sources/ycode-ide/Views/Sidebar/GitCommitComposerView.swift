import SwiftUI
import YcodeAssistant

@MainActor
struct GitCommitComposerView: View {
    @Binding var message: String
    let gitViewModel: GitViewModel
    let onCommit: () -> Void

    @State private var commitType = "feat"
    @State private var scope = ""
    @State private var title = ""
    @State private var bodyText = ""
    @State private var coAuthor = ""
    @State private var isSigning = false
    @State private var isAmending = false
    @State private var noVerify = false
    @State private var isGeneratingAI = false
    @State private var showAdvanced = false

    private let commitTypes = [
        "feat": "New Feature",
        "fix": "Bug Fix",
        "docs": "Documentation",
        "style": "Styling/Formatting",
        "refactor": "Refactoring",
        "test": "Testing",
        "chore": "Maintenance",
        "perf": "Performance",
        "ci": "CI/CD"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Commit Composer", systemImage: "pencil.and.outline")
                    .font(.headline)
                    .foregroundStyle(.orange)

                Label("Foundation Models", systemImage: "apple.intelligence")
                    .font(.caption2.bold())
                    .foregroundStyle(.purple)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.12), in: Capsule())

                Spacer()

                if isGeneratingAI {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button {
                        generateAICommitMessage()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.purple)
                            Text("AI Draft")
                                .font(.caption.bold())
                        }
                    }
                    .buttonStyle(.bordered)
                    .help("Review diff and suggest a commit message using Apple Intelligence Foundation Models")
                }
            }

            VStack(spacing: 10) {
                HStack {
                    Text("Type")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 50, alignment: .leading)

                    Picker("", selection: $commitType) {
                        ForEach(commitTypes.keys.sorted(), id: \.self) { key in
                            Text("\(key) - \(commitTypes[key] ?? "")").tag(key)
                        }
                    }
                    .pickerStyle(.menu)
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Scope")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                        TextField("e.g. ui", text: $scope)
                            .textFieldStyle(.roundedBorder)
                    }
                    .frame(width: 80)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Summary Title")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                        TextField("Summarize changes in 50 chars", text: $title)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Detailed Description (Body)")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    TextEditor(text: $bodyText)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 80, maxHeight: 150)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                }

                DisclosureGroup("Advanced & Options", isExpanded: $showAdvanced) {
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Co-Author")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                            TextField("Name <email>", text: $coAuthor)
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding(.top, 4)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Model")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("Foundation Models Only")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.purple)
                            }
                            Picker("", selection: Binding(
                                get: { FoundationModels.shared.selectedModel },
                                set: { FoundationModels.shared.selectedModel = $0 }
                            )) {
                                ForEach(AppleFoundationModel.allCases) { model in
                                    Text(model.rawValue).tag(model)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        HStack(spacing: 16) {
                            Toggle("Sign Commit", isOn: $isSigning)
                                .toggleStyle(.checkbox)
                            Toggle("Amend Last", isOn: $isAmending)
                                .toggleStyle(.checkbox)
                            Toggle("Bypass Hooks", isOn: $noVerify)
                                .toggleStyle(.checkbox)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .font(.caption)

                Button(action: {
                    message = assembleMessage()
                    onCommit()
                    title = ""
                    bodyText = ""
                }) {
                    Label("Commit to Local Branch", systemImage: "arrow.triangle.branch")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.large)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(12)
        .liquidGlass(style: .standard, cornerRadius: 10)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
        .onChange(of: commitType) { _, _ in updateParentBinding() }
        .onChange(of: scope) { _, _ in updateParentBinding() }
        .onChange(of: title) { _, _ in updateParentBinding() }
        .onChange(of: bodyText) { _, _ in updateParentBinding() }
        .onChange(of: coAuthor) { _, _ in updateParentBinding() }
        .onAppear {
            enforceFoundationModelsOnly()
        }
    }

    private func enforceFoundationModelsOnly() {
        let keysToCheck = [
            "commit_composer_provider",
            "commitComposerProvider",
            "commit_composer_model",
            "commitComposerModel",
            "git_commit_ai_provider",
            "git_commit_composer_provider",
            "source_control_ai_provider"
        ]
        for key in keysToCheck {
            if let val = UserDefaults.standard.string(forKey: key) {
                if val != "foundationModels" && val != "Apple Foundation Models" && val != AppleFoundationModel.afm3Core.rawValue && val != AppleFoundationModel.afm3CoreAdvanced.rawValue {
                    UserDefaults.standard.removeObject(forKey: key)
                }
            }
        }
        FoundationModels.shared.isEnabled = true
    }

    private func updateParentBinding() {
        message = assembleMessage()
    }

    private func assembleMessage() -> String {
        var msg = commitType
        let cleanScope = scope.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanScope.isEmpty {
            msg += "(\(cleanScope))"
        }
        msg += ": \(title.trimmingCharacters(in: .whitespacesAndNewlines))"

        let cleanBody = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanBody.isEmpty {
            msg += "\n\n\(cleanBody)"
        }

        let cleanCoAuthor = coAuthor.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanCoAuthor.isEmpty {
            msg += "\n\nCo-authored-by: \(cleanCoAuthor)"
        }

        return msg
    }

    private func generateAICommitMessage() {
        enforceFoundationModelsOnly()
        isGeneratingAI = true
        Task {
            do {
                let hunks = await gitViewModel.getDiff()
                var diffText = ""
                for hunk in hunks {
                    diffText += "Hunk: \(hunk.header)\n"
                    for line in hunk.lines {
                        diffText += "\(line)\n"
                    }
                }

                if diffText.isEmpty {
                    if let files = gitViewModel.status?.files {
                        diffText = "Modified Files:\n" + files.map { "\($0.status.rawValue): \($0.path)" }.joined(separator: "\n")
                    }
                }

                if diffText.isEmpty {
                    diffText = "No changes found in active working copy."
                }

                let prompt = """
                You are a Git commit expert powered strictly by Apple Intelligence Foundation Models. Review the following Git diff and generate a clear, professional, conventional commit message.
                Follow the Conventional Commits specification (e.g. feat(scope): message).
                Return ONLY a JSON object with the following keys, and NO other text, markdown formatting, or triple backticks:
                {
                  "type": "feat|fix|chore|docs|refactor|test|style|perf|ci",
                  "scope": "short scope if applicable, otherwise empty",
                  "title": "short summary under 50 characters",
                  "body": "optional longer description of changes"
                }

                Git Diff:
                \(diffText.prefix(2500))
                """

                
                FoundationModels.shared.isEnabled = true
                let response = try await FoundationModels.shared.generatePrivateResponse(
                    prompt: prompt,
                    systemPrompt: "You are a Git commit expert powered strictly by Apple Intelligence Foundation Models. Generate conventional commit messages in JSON format."
                )

                let cleanResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "```json", with: "")
                    .replacingOccurrences(of: "```", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if let data = cleanResponse.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                    if let t = json["type"], !t.isEmpty { commitType = t }
                    if let s = json["scope"] { scope = s }
                    if let ti = json["title"] { title = ti }
                    if let b = json["body"] { bodyText = b }
                } else {
                    commitType = "chore"
                    scope = ""
                    title = "update codebase"
                    bodyText = response
                }
            } catch {
                title = "code changes"
                bodyText = "Apple Foundation Models: \(error.localizedDescription)"
            }
            updateParentBinding()
            isGeneratingAI = false
        }
    }
}
