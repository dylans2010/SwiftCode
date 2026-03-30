import SwiftUI

struct EnvironmentSwitcherView: View {
    @AppStorage("com.swiftcode.debug.environment") private var currentEnv = "Production"
    @State private var showRestartAlert = false

    let environments = ["Production", "Staging", "Development", "QA"]

    var body: some View {
        List {
            Section {
                ForEach(environments, id: \.self) { env in
                    Button {
                        currentEnv = env
                        showRestartAlert = true
                    } label: {
                        HStack {
                            Text(env)
                                .foregroundStyle(.primary)
                            Spacer()
                            if currentEnv == env {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            } header: {
                Text("Select Environment")
            } footer: {
                Text("Changing environment requires an app restart to take effect across all services.")
            }

            Section("Current Configuration") {
                LabeledContent("API Base URL", value: apiBaseURL)
                LabeledContent("CDN Host", value: cdnHost)
            }
        }
        .navigationTitle("Environment")
        .alert("Restart Required", isPresented: $showRestartAlert) {
            Button("OK") { }
        } message: {
            Text("Environment set to \(currentEnv). Please restart the app manually.")
        }
    }

    private var apiBaseURL: String {
        switch currentEnv {
        case "Production": return "https://api.swiftcode.com"
        case "Staging": return "https://staging.api.swiftcode.com"
        case "Development": return "http://localhost:8080"
        default: return "https://api-qa.swiftcode.com"
        }
    }

    private var cdnHost: String {
        currentEnv == "Production" ? "cdn.swiftcode.com" : "cdn-debug.swiftcode.com"
    }
}
