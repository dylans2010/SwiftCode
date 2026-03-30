import SwiftUI

struct PermissionsCheckerView: View {
    @State private var permissions: [PermissionStatus] = [
        PermissionStatus(name: "Network Access", status: .granted, icon: "wifi"),
        PermissionStatus(name: "File System (Documents)", status: .granted, icon: "folder"),
        PermissionStatus(name: "Photo Library", status: .denied, icon: "photo"),
        PermissionStatus(name: "Camera", status: .notDetermined, icon: "camera"),
        PermissionStatus(name: "Notifications", status: .granted, icon: "bell")
    ]

    var body: some View {
        List {
            Section("System Permissions") {
                ForEach(permissions) { perm in
                    HStack {
                        Image(systemName: perm.icon)
                            .frame(width: 24)
                            .foregroundStyle(.blue)
                        Text(perm.name)
                        Spacer()
                        statusBadge(perm.status)
                    }
                }
            }

            Section("Actions") {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
        .navigationTitle("Permissions")
    }

    @ViewBuilder
    private func statusBadge(_ status: PHStatus) -> some View {
        Text(status.rawValue.uppercased())
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor(status).opacity(0.2))
            .foregroundStyle(statusColor(status))
            .clipShape(Capsule())
    }

    private func statusColor(_ status: PHStatus) -> Color {
        switch status {
        case .granted: return .green
        case .denied: return .red
        case .notDetermined: return .orange
        case .restricted: return .gray
        }
    }
}

enum PHStatus: String {
    case granted, denied, notDetermined, restricted
}

struct PermissionStatus: Identifiable {
    let id = UUID()
    let name: String
    let status: PHStatus
    let icon: String
}
