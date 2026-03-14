import SwiftUI

struct APIInspectorView: View {
    var body: some View {
        List {
            Section("Endpoints") {
                Text("OpenRouter: OK")
                Text("GitHub: OK")
            }
        }
        .navigationTitle("API Inspector")
    }
}
