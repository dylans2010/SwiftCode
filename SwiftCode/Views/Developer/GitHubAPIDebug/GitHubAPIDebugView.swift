import SwiftUI

struct GitHubAPIDebugView: View {
    var body: some View {
        Form {
            Section("Manual Testing") {
                Button("Test GET /user") {
                    // Test logic
                }
            }
        }
        .navigationTitle("GitHub API Debug")
    }
}
