#if os(macOS)
import SwiftUI
import YcodeDeviceModel
import YcodeIDECore

public struct DeviceHubGroupsView: View {
    private let hub: DevicesController

    @State private var groups: [DeviceGroup] = []
    @State private var newGroupName = ""
    @State private var renameText: [UUID: String] = [:]
    @State private var statusMessage: String?

    public init(hub: DevicesController) {
        self.hub = hub
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Device Groups")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Group simulators and boot or shut them down together. Groups are stored in SwiftCode preferences.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    TextField("New group name", text: $newGroupName)
                        .textFieldStyle(.roundedBorder)
                    Button("Create Group") {
                        createGroup()
                    }
                    .disabled(newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if groups.isEmpty {
                    Text("No groups yet. Create one, then add the selected device to it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(groups) { group in
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(group.name)
                                    .font(.headline)
                                Spacer()
                                Button("Boot All") {
                                    hub.bootGroup(group)
                                    statusMessage = "Booting “\(group.name)”…"
                                }
                                .controlSize(.small)
                                Button("Shut Down All") {
                                    hub.shutDownGroup(group)
                                    statusMessage = "Shutting down “\(group.name)”…"
                                }
                                .controlSize(.small)
                                Button("Delete", role: .destructive) {
                                    deleteGroup(group)
                                }
                                .controlSize(.small)
                            }
                            HStack {
                                TextField("Rename", text: renameBinding(for: group))
                                    .textFieldStyle(.roundedBorder)
                                Button("Rename") {
                                    renameGroup(group)
                                }
                                .controlSize(.small)
                                .disabled((renameText[group.id] ?? group.name).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                            if group.deviceIDs.isEmpty {
                                Text("No devices in this group yet.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(group.deviceIDs, id: \.self) { deviceID in
                                    HStack {
                                        Text(deviceName(for: deviceID))
                                            .font(.subheadline)
                                        Text(deviceState(for: deviceID))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Button("Remove") {
                                            removeDevice(deviceID, from: group)
                                        }
                                        .controlSize(.small)
                                    }
                                }
                            }
                            if let selected = hub.selected {
                                Button("Add Selected Device (“\(selected.name)”)") {
                                    addSelectedDevice(to: group)
                                }
                                .controlSize(.small)
                                .disabled(group.deviceIDs.contains(selected.identifier))
                            }
                        }
                        .padding(4)
                    }
                }

                if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .onAppear { reload() }
    }

    private func reload() {
        groups = hub.groupStore.loadGroups()
        for group in groups where renameText[group.id] == nil {
            renameText[group.id] = group.name
        }
    }

    private func renameBinding(for group: DeviceGroup) -> Binding<String> {
        Binding(
            get: { renameText[group.id] ?? group.name },
            set: { renameText[group.id] = $0 }
        )
    }

    private func createGroup() {
        let name = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if hub.groupStore.createGroup(name: name) != nil {
            newGroupName = ""
            statusMessage = "Created group “\(name)”."
            reload()
        } else {
            statusMessage = "A group named “\(name)” already exists."
        }
    }

    private func deleteGroup(_ group: DeviceGroup) {
        if hub.groupStore.deleteGroup(id: group.id) {
            statusMessage = "Deleted group “\(group.name)”."
            reload()
        }
    }

    private func renameGroup(_ group: DeviceGroup) {
        let name = (renameText[group.id] ?? group.name).trimmingCharacters(in: .whitespacesAndNewlines)
        if hub.groupStore.renameGroup(id: group.id, name: name) {
            statusMessage = "Renamed group to “\(name)”."
            reload()
        } else {
            statusMessage = "Could not rename “\(group.name)”. The name may already be in use."
        }
    }

    private func addSelectedDevice(to group: DeviceGroup) {
        guard let selected = hub.selected else { return }
        if hub.groupStore.addDevice(selected.identifier, toGroup: group.id) {
            statusMessage = "Added “\(selected.name)” to “\(group.name)”."
            reload()
        }
    }

    private func removeDevice(_ deviceID: String, from group: DeviceGroup) {
        if hub.groupStore.removeDevice(deviceID, fromGroup: group.id) {
            reload()
        }
    }

    private func deviceName(for deviceID: String) -> String {
        hub.allRows.first { $0.identifier == deviceID }?.name ?? deviceID
    }

    private func deviceState(for deviceID: String) -> String {
        hub.allRows.first { $0.identifier == deviceID }?.state ?? "missing"
    }
}
#endif
