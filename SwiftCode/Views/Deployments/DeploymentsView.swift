import SwiftUI

struct DeploymentsView: View {
    @EnvironmentObject private var projectManager: ProjectManager
    @State private var selectedPlatform: DeploymentPlatform = .netlify
    @State private var apiToken: String = ""
    @State private var customDomain: String = ""
    @State private var useCustomDomain: Bool = false
    @State private var logs: [DeploymentLogLine] = []
    @State private var isDeploying: Bool = false
    @State private var deploymentURL: String?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Deployments")
                    .font(.title2.bold())
                Spacer()
                if isDeploying {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Platform Selection
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Deployment Platform")
                                .font(.headline)

                            Picker("Platform", selection: $selectedPlatform) {
                                ForEach(DeploymentPlatform.allCases) { platform in
                                    Text(platform.rawValue).tag(platform)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(4)
                    }
                    .groupBoxStyle(ModernGroupBoxStyle())

                    // Configuration
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Configuration")
                                .font(.headline)

                            if selectedPlatform != .githubPages {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("API Token")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    SecureField("Enter API Token", text: $apiToken)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }

                            Toggle("Use Custom Domain", isOn: $useCustomDomain)

                            if useCustomDomain {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Domain")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    TextField("e.g. example.com", text: $customDomain)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }
                        }
                        .padding(4)
                    }
                    .groupBoxStyle(ModernGroupBoxStyle())

                    // Deploy Button
                    Button(action: startDeployment) {
                        HStack {
                            Image(systemName: "cloud.fill")
                            Text(isDeploying ? "Deploying..." : "Start Deployment")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isDeploying ? Color.gray : Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isDeploying || (selectedPlatform != .githubPages && apiToken.isEmpty))

                    // Result Section
                    if let deploymentURL = deploymentURL {
                        GroupBox {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text("Deployment Successful")
                                        .font(.headline)
                                }

                                Text("Your site is live at:")
                                    .font(.subheadline)

                                Link(deploymentURL, destination: URL(string: deploymentURL)!)
                                    .font(.system(.subheadline, design: .monospaced))
                                    .foregroundStyle(.blue)

                                Button {
                                    #if os(iOS)
                                    UIApplication.shared.open(URL(string: deploymentURL)!)
                                    #endif
                                } label: {
                                    Text("Open in Browser")
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(6)
                                }
                            }
                        }
                        .groupBoxStyle(ModernGroupBoxStyle())
                    }

                    if let errorMessage = errorMessage {
                        GroupBox {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                Text(errorMessage)
                                    .font(.subheadline)
                                    .foregroundStyle(.red)
                            }
                        }
                        .groupBoxStyle(ModernGroupBoxStyle())
                    }

                    // Logs Section
                    if !logs.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Deployment Logs")
                                .font(.headline)
                                .padding(.horizontal)

                            DeploymentLogsView(logs: logs)
                                .frame(height: 250)
                        }
                    }
                }
                .padding()
            }
        }
    }

    private func startDeployment() {
        guard let project = projectManager.activeProject else { return }

        isDeploying = true
        deploymentURL = nil
        errorMessage = nil
        logs = []

        Task {
            do {
                // Retrieve token from keychain if not provided in UI
                let tokenToUse: String?
                if selectedPlatform == .githubPages {
                    tokenToUse = DeploymentKeychainManager.shared.retrieveKey(service: .github)
                } else if selectedPlatform == .netlify {
                    tokenToUse = !apiToken.isEmpty ? apiToken : DeploymentKeychainManager.shared.retrieveKey(service: .netlify)
                } else if selectedPlatform == .vercel {
                    tokenToUse = !apiToken.isEmpty ? apiToken : DeploymentKeychainManager.shared.retrieveKey(service: .vercel)
                } else {
                    tokenToUse = apiToken
                }

                let result = try await DeploymentTargets.shared.deploy(
                    project: project,
                    platform: selectedPlatform,
                    token: tokenToUse,
                    domain: useCustomDomain ? customDomain : nil
                ) { message in
                    DispatchQueue.main.async {
                        logs.append(DeploymentLogLine(timestamp: Date(), message: message, isError: false))
                    }
                }

                DispatchQueue.main.async {
                    isDeploying = false
                    if result.success {
                        deploymentURL = result.url
                    } else {
                        errorMessage = result.errorMessage
                        logs.append(DeploymentLogLine(timestamp: Date(), message: result.errorMessage ?? "Unknown error", isError: true))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    isDeploying = false
                    errorMessage = error.localizedDescription
                    logs.append(DeploymentLogLine(timestamp: Date(), message: error.localizedDescription, isError: true))
                }
            }
        }
    }
}

#Preview {
    DeploymentsView()
        .environmentObject(ProjectManager.shared)
}
