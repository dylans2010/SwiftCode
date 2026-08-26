import SwiftUI

struct MacPermissionsView: View {
    let mac: PairedMacDevice
    @StateObject private var permissionManager = ConnectPermissionManager.shared

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.07, green: 0.07, blue: 0.12),
                        Color(red: 0.10, green: 0.10, blue: 0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                List {
                    Section {
                        ForEach(ConnectPermission.allCases) { perm in
                            Toggle(isOn: Binding(
                                get: { permissionManager.hasPermission(perm, for: mac.id) },
                                set: { permissionManager.setPermission(perm, isGranted: $0, for: mac.id) }
                            )) {
                                Label {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(perm.displayName)
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                        if perm.isSensitive {
                                            Text("Requires explicit authorization")
                                                .font(.caption2)
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                } icon: {
                                    Image(systemName: perm.iconName)
                                        .foregroundStyle(perm.isSensitive ? .orange : .cyan)
                                }
                            }
                            .listRowBackground(Color.white.opacity(0.05))
                        }
                    } header: {
                        Text("Granular Capability Authorization")
                            .foregroundStyle(.secondary)
                    } footer: {
                        Text("Only explicitly authorized capabilities will be granted to this iOS device over the SwiftCode Connect protocol.")
                            .foregroundStyle(.tertiary)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Permissions: \(mac.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
