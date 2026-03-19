import SwiftUI

struct MemberManagementView: View {
    @ObservedObject var manager: CollaborationManager
    let actorID: String

    @State private var showingAddMember = false
    @State private var newMemberID = ""
    @State private var selectedRole: CollaborationRole = .member

    var body: some View {
        List {
            Section {
                Button {
                    showingAddMember = true
                } label: {
                    Label("Add New Member", systemImage: "person.badge.plus")
                }
            }

            Section("Current Members") {
                ForEach(manager.permissions.memberRoles.keys.sorted(), id: \.self) { memberID in
                    memberRow(for: memberID)
                }
            }

            Section("Roles & Permissions") {
                Text("Owners have full control over the project.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Admins can manage members and branches.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Members can commit, push, and create PRs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Members")
        .sheet(isPresented: $showingAddMember) {
            addMemberSheet
        }
    }

    @ViewBuilder
    private func memberRow(for memberID: String) -> some View {
        let role = manager.permissions.memberRoles[memberID] ?? .member
        HStack {
            Image(systemName: "person.crop.circle")
                .font(.title2)
                .foregroundStyle(roleColor(for: role))

            VStack(alignment: .leading, spacing: 2) {
                Text(memberID).font(.headline)
                Text(role.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if memberID != actorID {
                Menu {
                    ForEach(CollaborationRole.allCases, id: \.self) { newRole in
                        Button("Change to \(newRole.rawValue.capitalized)") {
                            _ = manager.permissions.assignRole(newRole, to: memberID, by: actorID)
                            manager.saveState()
                        }
                    }

                    Button("Remove", role: .destructive) {
                        _ = manager.permissions.removeMember(memberID, by: actorID)
                        manager.saveState()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("You")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1), in: Capsule())
            }
        }
        .padding(.vertical, 4)
    }

    private func roleColor(for role: CollaborationRole) -> Color {
        switch role {
        case .owner: return .orange
        case .admin: return .blue
        case .member: return .secondary
        }
    }

    private var addMemberSheet: some View {
        NavigationStack {
            Form {
                Section("Collaborator Details") {
                    TextField("Username / Device ID", text: $newMemberID)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Picker("Role", selection: $selectedRole) {
                        ForEach(CollaborationRole.allCases, id: \.self) { role in
                            Text(role.rawValue.capitalized).tag(role)
                        }
                    }
                }
            }
            .navigationTitle("Add Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingAddMember = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        manager.invite(memberID: newMemberID, role: selectedRole, actorID: actorID)
                        showingAddMember = false
                        newMemberID = ""
                    }
                    .disabled(newMemberID.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
