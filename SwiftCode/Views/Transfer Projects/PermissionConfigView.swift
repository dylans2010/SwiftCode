import SwiftUI

struct PermissionConfigView: View {
    @Binding var permission: TransferPermission

    var body: some View {
        Group {
            Picker("Preset", selection: Binding(get: { permission.preset }, set: { permission = .makePreset($0) })) {
                ForEach(TransferPermission.AccessPreset.allCases) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }
            permissionToggle("View Files", value: $permission.fileSystem.viewFiles)
            permissionToggle("Edit Files", value: $permission.fileSystem.editFiles)
            permissionToggle("Create Files", value: $permission.fileSystem.createFiles)
            permissionToggle("Delete Files", value: $permission.fileSystem.deleteFiles)
            permissionToggle("Commit", value: $permission.versionControl.commit)
            permissionToggle("Push", value: $permission.versionControl.push)
            permissionToggle("Agent Access", value: $permission.agent.allowAgentAccess)
            permissionToggle("Agent File Modification", value: $permission.agent.allowAgentFileModification)
            permissionToggle("Agent Run Commands", value: $permission.agent.allowAgentToRunCommands)

            if permission.agent.allowAgentToRunCommands || permission.versionControl.push {
                Label("High risk permissions enabled", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        }
    }

    private func permissionToggle(_ title: String, value: Binding<Bool>) -> some View {
        Toggle(title, isOn: value)
    }
}
