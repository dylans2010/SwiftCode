import SwiftUI

struct ActivityLogView: View {
    @ObservedObject var manager: CollaborationManager
    @State private var selectedKind: CollaborationActivity.Kind?
    @State private var actorFilter = ""
    @State private var showLast24hOnly = false

    var body: some View {
        List {
            Section("Notifications") {
                if manager.notifications.isEmpty { Text("No Notifications Yet").foregroundStyle(.secondary) }
                ForEach(manager.notifications) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title).font(.headline)
                        Text(item.detail).font(.caption)
                        Text(item.timestamp.formatted(date: .abbreviated, time: .shortened)).font(.caption2).foregroundStyle(.secondary)
                    }
                    .swipeActions {
                        Button("Read") { manager.markNotificationRead(item.id) }.tint(.blue)
                    }
                }
            }

            Section("Filters") {
                TextField("Filter by user", text: $actorFilter)
                Toggle("Only last 24 hours", isOn: $showLast24hOnly)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        filterChip(title: "All", kind: nil)
                        ForEach(CollaborationActivity.Kind.allCases, id: \.self) { kind in
                            filterChip(title: kind.rawValue.capitalized, kind: kind)
                        }
                    }
                }
            }

            Section("Timeline") {
                ForEach(filteredActivity) { entry in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(entry.title).font(.headline)
                            Spacer()
                            Text(entry.kind.rawValue.capitalized).font(.caption2).foregroundStyle(.secondary)
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

    private var filteredActivity: [CollaborationActivity] {
        manager.activityLog.filter {
            (selectedKind == nil || $0.kind == selectedKind) &&
            (actorFilter.isEmpty || $0.actorID.localizedCaseInsensitiveContains(actorFilter)) &&
            (!showLast24hOnly || $0.timestamp >= Date().addingTimeInterval(-86400))
        }
    }

    private func filterChip(title: String, kind: CollaborationActivity.Kind?) -> some View {
        Button(title) { selectedKind = kind }
            .buttonStyle(.borderedProminent)
            .tint(selectedKind == kind ? .blue : .gray)
    }
}

private extension CollaborationActivity.Kind {
    static var allCases: [CollaborationActivity.Kind] {
        [.branch, .commit, .review, .pullRequest, .pullRequestReview, .sync, .invite, .permissions, .conflict, .fileLock, .chat, .notification, .presence]
    }
}
