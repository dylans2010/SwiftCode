import SwiftUI

struct MemberManagementView: View {
    @ObservedObject var manager: CollaborationManager
    let actorID: String

    var body: some View {
        List {
            Section("Management Actions") {
                NavigationLink {
                    InviteMembersView(manager: manager, actorID: actorID)
                } label: {
                    Label("Invite New Members", systemImage: "person.badge.plus.fill")
                }
            }

            Section("Current Collaborators") {
                if manager.permissions.memberRoles.isEmpty {
                    Text("No members registered.")
                        .foregroundStyle(.secondary)
                }
                ForEach(manager.permissions.memberRoles.keys.sorted(), id: \.self) { memberID in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(memberID).font(.headline)
                            Text(manager.permissions.memberRoles[memberID]?.rawValue.capitalized ?? "Unknown")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if memberID != actorID {
                            Menu {
                                ForEach(CollaborationRole.allCases, id: \.self) { role in
                                    Button("Make \(role.rawValue.capitalized)") {
                                        _ = manager.permissions.assignRole(role, to: memberID, by: actorID)
                                    }
                                }
                                Button("Remove Collaborator", role: .destructive) {
                                    _ = manager.permissions.removeMember(memberID, by: actorID)
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundStyle(.blue)
                            }
                        } else {
                            Text("(You)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Permissions Summary") {
                Text("Owners and Admins can manage members, create branches, and merge pull requests. Members are restricted to viewing, committing, and pushing/pulling.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Member Management")
    }
}
