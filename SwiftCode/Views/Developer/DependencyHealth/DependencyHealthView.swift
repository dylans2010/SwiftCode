import SwiftUI

struct DependencyHealthView: View {
    @State private var dependencies: [DependencyHealth] = [
        DependencyHealth(name: "ZIPFoundation", version: "0.9.0", status: .healthy),
        DependencyHealth(name: "mlx-swift", version: "0.21.0", status: .healthy),
        DependencyHealth(name: "SwiftUI", version: "System", status: .healthy),
        DependencyHealth(name: "Combine", version: "System", status: .healthy)
    ]

    var body: some View {
        List {
            Section("Status Summary") {
                HStack {
                    Label("All Systems Operational", systemImage: "checkmark.shield.fill")
                        .foregroundStyle(.green)
                    Spacer()
                }
            }

            Section("Direct Dependencies") {
                ForEach(dependencies) { dep in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(dep.name)
                                .font(.subheadline.bold())
                            Text("Version: \(dep.version)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        statusBadge(dep.status)
                    }
                }
            }
        }
        .navigationTitle("Dependency Health")
    }

    @ViewBuilder
    private func statusBadge(_ status: HealthStatus) -> some View {
        Text(status.rawValue.uppercased())
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor(status).opacity(0.2))
            .foregroundStyle(statusColor(status))
            .clipShape(Capsule())
    }

    private func statusColor(_ status: HealthStatus) -> Color {
        switch status {
        case .healthy: return .green
        case .outdated: return .orange
        case .vulnerable: return .red
        }
    }
}

enum HealthStatus: String {
    case healthy = "Healthy"
    case outdated = "Outdated"
    case vulnerable = "Vulnerable"
}

struct DependencyHealth: Identifiable {
    let id = UUID()
    let name: String
    let version: String
    let status: HealthStatus
}
