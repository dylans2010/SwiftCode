import SwiftUI

struct BuildDiagnosticsView: View {
    @State private var diagnostics: [BuildDiagnostic] = [
        BuildDiagnostic(title: "Architecture", detail: "arm64", status: .info),
        BuildDiagnostic(title: "Swift Version", detail: "5.10", status: .info),
        BuildDiagnostic(title: "SDK Path", detail: "/Applications/Xcode.app/.../iPhoneOS.sdk", status: .info),
        BuildDiagnostic(title: "Signing Identity", detail: "Apple Development: ...", status: .info),
        BuildDiagnostic(title: "Derived Data", detail: "4.2 GB", status: .warning)
    ]

    var body: some View {
        List {
            Section("Build Configuration") {
                ForEach(diagnostics) { diag in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(diag.title)
                                .font(.subheadline.bold())
                            Spacer()
                            if diag.status == .warning {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.caption)
                            }
                        }
                        Text(diag.detail)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }

            Section("Actions") {
                Button("Rebuild Index") { }
                Button("Clean Build Folder", role: .destructive) { }
            }
        }
        .navigationTitle("Build Diagnostics")
    }
}

struct BuildDiagnostic: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let status: DiagnosticStatus
}

enum DiagnosticStatus {
    case info, warning, error
}
