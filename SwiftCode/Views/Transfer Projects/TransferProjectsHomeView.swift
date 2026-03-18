import SwiftUI
import MultipeerConnectivity

struct TransferProjectsHomeView: View {
    @EnvironmentObject private var projectManager: ProjectManager
    @StateObject private var transferManager = ProjectTransferManager.shared
    @StateObject private var peerManager = PeerSessionManager.shared
    @State private var selectedPeer: MCPeerID?
    @State private var permission = TransferPermission.makePreset(.limitedEdit)

    var body: some View {
        List {
            if let project = projectManager.activeProject {
                Section("Active Project") {
                    Text(project.name)
                    PermissionConfigView(permission: $permission)
                    NavigationLink("Choose Device") {
                        DevicePickerView(selectedPeer: $selectedPeer)
                    }
                    if let selectedPeer {
                        Button("Transfer to \(selectedPeer.displayName)") {
                            Task { try? await transferManager.startTransfer(project: project, to: selectedPeer, permission: permission) }
                        }
                    }
                }
            }
            Section("Incoming") {
                if transferManager.incomingSession != nil {
                    IncomingTransferView()
                } else {
                    Text("No incoming transfers")
                        .foregroundStyle(.secondary)
                }
            }
            Section("Progress") {
                TransferProgressView()
            }
        }
        .navigationTitle("Transfer Projects")
    }
}
