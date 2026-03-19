import SwiftUI

struct ActivityLogView: View {
    @ObservedObject var manager: CollaborationManager

    var body: some View {
        List {
            Section("Notifications") {
                if manager.notifications.isEmpty {
                    Text("No notifications yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(manager.notifications) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title).font(.headline)
                        Text(item.detail).font(.caption)
                        Text(item.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .swipeActions {
                        Button("Read") { manager.markNotificationRead(item.id) }
                            .tint(.blue)
                    }
                }
            }

            Section("Activity Log") {
                ForEach(manager.activityLog) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(entry.title).font(.headline)
                            Spacer()
                            Text(entry.kind.rawValue.capitalized)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text(entry.detail)
                        Text("\(entry.actorID) • \(entry.timestamp.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Activity Log")
    }
}
