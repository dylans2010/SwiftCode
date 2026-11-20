import SwiftUI
import YcodeAssistant

/// Assist Settings section that installs, lists and uninstalls SwiftCode System Skills.
struct SystemSkillsInstallSection: View {
    @State private var manager = SystemSkillInstallManager.shared
    @State private var showCatalog = false
    @State private var confirmUninstall = false

    var body: some View {
        let available = manager.availableSkills()
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.teal.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: "square.and.arrow.down.on.square")
                        .foregroundColor(.teal)
                        .font(.system(size: 16, weight: .bold))
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("System Skills")
                            .font(.system(size: 13, weight: .semibold))
                        Text("\(manager.installedCount())/\(available.count) Installed")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.teal)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.teal.opacity(0.12), in: Capsule())
                    }
                    Text("\(available.count) SwiftCode playbooks across \(manager.categories.count) categories (auth, UI design, testing, docs, security…)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task { await manager.installAll() }
                } label: {
                    Label(manager.allInstalled ? "Reinstall System Skills" : "Install System Skills", systemImage: "arrow.down.circle")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(manager.isWorking || available.isEmpty)
                .accessibilityIdentifier("installSystemSkillsButton")

                Button(role: .destructive) {
                    confirmUninstall = true
                } label: {
                    Label("Uninstall", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(manager.isWorking || manager.installedCount() == 0)
                .accessibilityIdentifier("uninstallSystemSkillsButton")
            }

            if manager.isWorking {
                ProgressView(value: manager.progress)
                    .progressViewStyle(.linear)
            }
            if let error = manager.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.red)
            } else if let message = manager.lastMessage {
                Label(message, systemImage: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }

            DisclosureGroup(isExpanded: $showCatalog) {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(manager.categories, id: \.self) { category in
                        Text(category)
                            .font(.caption.weight(.semibold))
                            .padding(.top, 6)
                        ForEach(available.filter { $0.category == category }) { skill in
                            SystemSkillRow(skill: skill, manager: manager)
                        }
                    }
                }
            } label: {
                Text("Browse System Skills")
                    .font(.caption)
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.02), in: RoundedRectangle(cornerRadius: 10))
        .onAppear { manager.refreshInstalledState() }
        .confirmationDialog("Uninstall all System Skills?", isPresented: $confirmUninstall) {
            Button("Uninstall \(manager.installedCount()) Skills", role: .destructive) {
                Task { await manager.uninstallAll() }
            }
        } message: {
            Text("Only SwiftCode System Skills are removed. Your own skills are not touched.")
        }
    }
}

private struct SystemSkillRow: View {
    let skill: SystemSkill
    let manager: SystemSkillInstallManager

    var body: some View {
        let installed = manager.isInstalled(skill)
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: installed ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(installed ? Color.green : Color.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(skill.name)
                    .font(.caption.monospaced())
                Text(skill.description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Button(installed ? "Uninstall" : "Install") {
                Task {
                    if installed { _ = await manager.uninstall(skill) } else { _ = await manager.install(skill) }
                }
            }
            .buttonStyle(.borderless)
            .font(.caption2)
            .disabled(manager.isWorking)
            .accessibilityLabel(installed ? "Uninstall \(skill.name)" : "Install \(skill.name)")
        }
        .padding(.vertical, 2)
    }
}
