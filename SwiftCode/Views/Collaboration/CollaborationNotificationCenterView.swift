import SwiftUI

struct CollaborationNotificationCenterView: View {
    @ObservedObject var manager: CollaborationManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if manager.notifications.isEmpty {
                    ContentUnavailableView("No Notifications", systemImage: "bell.slash", description: Text("You're all caught up!"))
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(manager.notifications) { notification in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(notification.title)
                                    .font(.subheadline.bold())
                                Spacer()
                                if !notification.isRead {
                                    Circle()
                                        .fill(Color.orange)
                                        .frame(width: 8, height: 8)
                                }
                            }
                            Text(notification.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(notification.timestamp, style: .relative)
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(notification.isRead ? Color.white.opacity(0.02) : Color.blue.opacity(0.05))
                        .swipeActions(edge: .trailing) {
                            Button {
                                manager.markNotificationRead(notification.id)
                            } label: {
                                Label("Read", systemImage: "checkmark.circle")
                            }
                            .tint(.blue)
                        }
                    }
                }
            }
            .background(Color(red: 0.05, green: 0.05, blue: 0.07))
            .scrollContentBackground(.hidden)
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
