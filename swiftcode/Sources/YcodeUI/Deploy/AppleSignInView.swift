import YcodeXcodebuild
import YcodeIDECore
import YcodeAssistant
import SwiftUI
import UniformTypeIdentifiers

@MainActor
public struct AppleSignInView: View {
    public init() {}
    @State private var appleID = ""
    @State private var password = ""
    @State private var twoFactorCode = ""

    @State private var apiKeyLabel = ""
    @State private var apiKeyID = ""
    @State private var apiKeyIssuerID = ""
    @State private var apiKeyFileName = ""
    @State private var apiKeyPEM = ""

    @State private var targetAppPath = ""
    @State private var selectedCertificateName = ""
    @State private var codesignStatusMessage = ""
    @State private var isCodesigning = false

    @State private var p12Password = ""
    @State private var p12ExportStatusMessage = ""
    @State private var p12ExportSuccess = false

    @Environment(\.dismiss) private var dismiss

    private var manager: AppleSignInManager {
        AppleSignInManager.shared
    }

    /// True while the verification UI should be shown — including the
    /// `.loading` states of "send code" / "verify", so the section does not
    /// flicker back to the password form mid-request.
    private var awaitingVerification: Bool {
        manager.sessionState == .verificationRequired
            || (manager.sessionState == .loading && manager.twoFactorContext != nil)
    }

    private func pickAPIKeyFile() {
        let panel = NSOpenPanel()
        let p8Type = UTType(filenameExtension: "p8") ?? .data
        panel.allowedContentTypes = [p8Type]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = "Choose"
        panel.message = "Select your App Store Connect API key (.p8) downloaded from App Store Connect → Users and Access → Integrations."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let contents = try String(contentsOf: url, encoding: .utf8)
            guard contents.contains("PRIVATE KEY") else {
                manager.lastError = "The selected file does not look like a PEM private key."
                return
            }
            apiKeyPEM = contents
            apiKeyFileName = url.lastPathComponent
            // AuthKey_XXXXXXXXXX.p8 embeds the Key ID in the filename.
            if apiKeyID.isEmpty {
                let base = url.deletingPathExtension().lastPathComponent
                if base.hasPrefix("AuthKey_"), base.count > 8 {
                    apiKeyID = String(base.dropFirst(8))
                }
            }
        } catch {
            manager.lastError = "Could not read \(url.lastPathComponent): \(error.localizedDescription)"
        }
    }

    private func saveP12File(account: AppleSignInManager.AppleDeveloperAccount) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pkcs12]
        savePanel.nameFieldStringValue = "\(account.appleID)_dev_cert.p12"
        savePanel.title = "Save Developer PKCS12 Certificate"
        savePanel.prompt = "Save"

        if savePanel.runModal() == .OK, let url = savePanel.url {
            Task {
                do {
                    let secureKey = "apple_dev_key_\(account.appleID)_\(account.teamID)"
                    let savedPrivateKey = KeychainService.shared.get(forKey: secureKey) ?? ""
                    let certContent = account.certificates?.first?.content ?? ""

                    try await manager.generateP12File(
                        appleID: account.appleID,
                        teamID: account.teamID,
                        certificateName: account.certificateName,
                        certContentBase64: certContent,
                        privateKeyPEM: savedPrivateKey,
                        outputURL: url,
                        passwordForP12: p12Password
                    )

                    p12ExportStatusMessage = "Successfully generated and saved .p12 file!"
                    p12ExportSuccess = true
                } catch {
                    p12ExportStatusMessage = "Export failed: \(error.localizedDescription)"
                    p12ExportSuccess = false
                }
            }
        }
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    GroupBox {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Label("Sign In with Apple Account", systemImage: "person.crop.circle.badge.plus")
                                    .font(.headline)
                                    .foregroundColor(.orange)
                                Spacer()
                            }

                            Text("Sign in with your Apple ID to add your Developer Teams for signing. If your account uses two-factor authentication, Apple will ask for the verification code shown on your trusted devices.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if !awaitingVerification {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Apple ID (Email) *")
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                    TextField("e.g. developer@apple.com", text: $appleID)
                                        .textFieldStyle(.roundedBorder)
                                        .autocorrectionDisabled()
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Password *")
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                    SecureField("Apple Account password", text: $password)
                                        .textFieldStyle(.roundedBorder)
                                }

                                Button {
                                    Task {
                                        await manager.signInWithAppleID(appleID: appleID, password: password)
                                    }
                                } label: {
                                    HStack {
                                        if manager.sessionState == .loading {
                                            ProgressView().controlSize(.small)
                                                .padding(.trailing, 4)
                                        }
                                        Text("Sign In")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                                .tint(.orange)
                                .disabled(appleID.isEmpty || password.isEmpty || manager.sessionState == .loading)
                            } else {
                                twoFactorSection
                            }
                        }
                        .padding()
                    }
                    .groupBoxStyle(ModernGroupBoxStyle())

                    GroupBox {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Label("App Store Connect API Key", systemImage: "key.fill")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                Spacer()
                            }

                            Text("Add an App Store Connect API key (.p8) instead of an Apple ID sign-in. Create one in App Store Connect → Users and Access → Integrations (team keys) or your user profile (individual keys). SwiftCode verifies the key against Apple's API before storing it.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Label (Optional)")
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                    TextField("e.g. Work Account", text: $apiKeyLabel)
                                        .textFieldStyle(.roundedBorder)
                                }
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Key ID *")
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                    TextField("e.g. ABC123XYZ", text: $apiKeyID)
                                        .textFieldStyle(.roundedBorder)
                                        .autocorrectionDisabled()
                                }
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Issuer ID *")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                TextField("e.g. e55f462a-96fe-1a63-e053-0824d011072a", text: $apiKeyIssuerID)
                                    .textFieldStyle(.roundedBorder)
                                    .autocorrectionDisabled()
                            }

                            HStack(spacing: 12) {
                                Button("Choose .p8 File…") {
                                    pickAPIKeyFile()
                                }
                                .buttonStyle(.bordered)

                                if !apiKeyFileName.isEmpty {
                                    Label(apiKeyFileName, systemImage: "checkmark.seal.fill")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                            }

                            Button {
                                Task {
                                    await manager.addAppStoreConnectAPIKey(
                                        label: apiKeyLabel,
                                        keyID: apiKeyID,
                                        issuerID: apiKeyIssuerID,
                                        privateKeyPEM: apiKeyPEM
                                    )
                                    if manager.sessionState == .signedIn {
                                        apiKeyLabel = ""
                                        apiKeyID = ""
                                        apiKeyIssuerID = ""
                                        apiKeyFileName = ""
                                        apiKeyPEM = ""
                                    }
                                }
                            } label: {
                                HStack {
                                    if manager.sessionState == .loading {
                                        ProgressView().controlSize(.small)
                                            .padding(.trailing, 4)
                                    }
                                    Text("Verify & Add API Key")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .tint(.blue)
                            .disabled(apiKeyID.isEmpty || apiKeyIssuerID.isEmpty || apiKeyPEM.isEmpty || manager.sessionState == .loading)
                        }
                        .padding()
                    }
                    .groupBoxStyle(ModernGroupBoxStyle())

                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Label("Security & Local Storage", systemImage: "lock.shield.fill")
                                    .font(.headline)
                                    .foregroundColor(.green)
                                Spacer()
                            }

                            Text("Passwords and keys are kept locally on your Mac in the credential store and are only sent to Apple's own servers (idmsa.apple.com, appstoreconnect.apple.com, developer.apple.com, api.appstoreconnect.apple.com) to sign in and verify your teams.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    }
                    .groupBoxStyle(ModernGroupBoxStyle())

                    if !manager.developerAccounts.isEmpty {
                        GroupBox {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Label("Connected Developer Teams", systemImage: "person.crop.circle.badge.checkmark")
                                        .font(.headline)
                                        .foregroundColor(.blue)
                                    Spacer()
                                }

                                ForEach(manager.developerAccounts) { account in
                                    ConnectedAccountRowView(account: account) {
                                        if let index = manager.developerAccounts.firstIndex(where: { $0.id == account.id }) {
                                            manager.removeAccount(at: IndexSet(integer: index))
                                        }
                                    }

                                    if account.id != manager.developerAccounts.last?.id {
                                        Divider()
                                    }
                                }
                            }
                            .padding()
                        }
                        .groupBoxStyle(ModernGroupBoxStyle())

                        GroupBox {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Label("Export PKCS12 (.p12) Certificate", systemImage: "key.fill")
                                        .font(.headline)
                                        .foregroundColor(.green)
                                    Spacer()
                                }

                                Text("Bundle a signing certificate with its private key into a standard .p12 file using OpenSSL. This only works for accounts whose private key is stored locally (the .p8 App Store Connect key cannot sign development certificates).")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                SecureField("Secure .p12 Password", text: $p12Password)
                                    .textFieldStyle(.roundedBorder)

                                ForEach(manager.developerAccounts) { account in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(account.teamName)
                                                .font(.body.bold())
                                            Text(account.appleID)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Button("Generate & Save .p12") {
                                            saveP12File(account: account)
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(.green)
                                    }
                                    .padding(8)
                                    .background(Color.secondary.opacity(0.05))
                                    .cornerRadius(6)
                                }

                                if !p12ExportStatusMessage.isEmpty {
                                    Text(p12ExportStatusMessage)
                                        .font(.caption.bold())
                                        .foregroundStyle(p12ExportSuccess ? .green : .red)
                                }
                            }
                            .padding()
                        }
                        .groupBoxStyle(ModernGroupBoxStyle())

                        GroupBox {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Label("Real App Codesign Utility", systemImage: "signature")
                                        .font(.headline)
                                        .foregroundColor(.purple)
                                    Spacer()
                                }

                                Text("Sign any macOS app bundle or binary file on this Mac using the certificates retrieved above.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text("Note: The corresponding private key for the selected signing certificate must already be installed in your macOS Keychain for codesigning to succeed.")
                                    .font(.caption)
                                    .foregroundStyle(.orange)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Target Application Path")
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                    TextField("e.g. /path/to/MyApp.app", text: $targetAppPath)
                                        .textFieldStyle(.roundedBorder)
                                        .autocorrectionDisabled()
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Signing Identity")
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                    Picker("Identity", selection: $selectedCertificateName) {
                                        Text("Select an identity").tag("")
                                        ForEach(manager.developerAccounts) { account in
                                            if let certificates = account.certificates {
                                                ForEach(certificates) { cert in
                                                    Text("\(cert.name) (\(account.teamName))").tag(cert.name)
                                                }
                                            }
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }

                                Button {
                                    Task {
                                        isCodesigning = true
                                        codesignStatusMessage = "Signing..."
                                        do {
                                            let success = try await manager.codesign(
                                                appPath: targetAppPath,
                                                withCertificateName: selectedCertificateName
                                            )
                                            if success {
                                                codesignStatusMessage = "Successfully codesigned!"
                                            } else {
                                                codesignStatusMessage = "Codesign failed."
                                            }
                                        } catch {
                                            codesignStatusMessage = "Error: \(error.localizedDescription)"
                                        }
                                        isCodesigning = false
                                    }
                                } label: {
                                    HStack {
                                        if isCodesigning {
                                            ProgressView().controlSize(.small)
                                                .padding(.trailing, 4)
                                        }
                                        Text("Codesign Application Bundle")
                                            .fontWeight(.bold)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                                .tint(.purple)
                                .disabled(targetAppPath.isEmpty || selectedCertificateName.isEmpty || isCodesigning)

                                if !codesignStatusMessage.isEmpty {
                                    Text(codesignStatusMessage)
                                        .font(.caption.bold())
                                        .foregroundStyle(codesignStatusMessage.contains("Successfully") ? .green : .red)
                                        .padding(.top, 2)
                                }
                            }
                            .padding()
                        }
                        .groupBoxStyle(ModernGroupBoxStyle())
                    }

                    if let error = manager.lastError {
                        GroupBox {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                Text(error)
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                            .padding()
                        }
                        .groupBoxStyle(ModernGroupBoxStyle())
                    }
                }
                .padding(24)
            }
            .background(Color(NSColor.windowBackgroundColor))
            .navigationTitle("Apple Developer Accounts")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 550, idealWidth: 600, maxWidth: 800, minHeight: 500, idealHeight: 700, maxHeight: 900)
    }

    /// The two-factor / two-step verification step shown after Apple answers
    /// the password request with HTTP 409.
    @ViewBuilder
    private var twoFactorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let context = manager.twoFactorContext {
                Text("Two-Factor Verification")
                    .font(.subheadline.bold())
                    .foregroundColor(.orange)

                Text("Enter the \(context.codeLength)-digit code Apple sent to your trusted device, or choose a phone number to receive it by text message.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Send code to", selection: Binding(
                    get: { manager.twoFactorDelivery },
                    set: { manager.selectTwoFactorDelivery($0) }
                )) {
                    if !context.phones.isEmpty {
                        Text("Code shown on my devices").tag(AppleTwoFactorDelivery.trustedDevice)
                    }
                    ForEach(context.phones) { phone in
                        Text("Text code to \(phone.numberWithDialCode.isEmpty ? phone.id : phone.numberWithDialCode)")
                            .tag(AppleTwoFactorDelivery.phone(phone.id))
                    }
                    ForEach(context.devices) { device in
                        Text("Code on \(device.name)").tag(AppleTwoFactorDelivery.device(device.id))
                    }
                }
                .pickerStyle(.menu)

                HStack(spacing: 12) {
                    TextField("\(context.codeLength)-digit code", text: $twoFactorCode)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3.monospaced())
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 220)
                        .autocorrectionDisabled()

                    Button("Send Code") {
                        Task { await manager.requestTwoFactorCode() }
                    }
                    .disabled(manager.twoFactorDelivery == .trustedDevice || manager.sessionState == .loading)
                    .help(manager.twoFactorDelivery == .trustedDevice
                          ? "The code was already pushed to your trusted devices."
                          : "Ask Apple to send a new code to the selected destination.")
                }

                Button {
                    Task {
                        await manager.verifyTwoFactorCode(twoFactorCode)
                        if manager.sessionState == .signedIn {
                            twoFactorCode = ""
                        }
                    }
                } label: {
                    HStack {
                        if manager.sessionState == .loading {
                            ProgressView().controlSize(.small)
                                .padding(.trailing, 4)
                        }
                        Text("Verify & Sign In")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(twoFactorCode.count < context.codeLength || manager.sessionState == .loading)

                Button("Back") {
                    manager.cancelPendingSignIn()
                }
                .buttonStyle(.link)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.06))
        .cornerRadius(8)
    }
}

@MainActor
struct ConnectedAccountRowView: View {
    let account: AppleSignInManager.AppleDeveloperAccount
    let onRemove: () -> Void

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.teamName)
                        .font(.body.bold())
                    Text("\(account.appleID) (Team ID: \(account.teamID))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                if account.authMethod == "appStoreConnectAPIKey" {
                    Text("API Key")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15))
                        .foregroundStyle(.blue)
                        .cornerRadius(4)
                }

                Button(role: .destructive) {
                    onRemove()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help("Remove Account")
                .padding(.trailing, 8)

                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

            if let certificates = account.certificates, !certificates.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Active Signing Certificates:")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    ForEach(certificates) { cert in
                        HStack {
                            Image(systemName: "key.fill")
                                .foregroundStyle(.orange)
                                .imageScale(.small)
                            Text("\(cert.name) (\(cert.type))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 4)
            } else if account.authMethod == "appleID" {
                Text("Teams from your Apple Account sign-in. Signing certificates are managed by your Apple ID in Xcode or the Developer portal.")
                    .font(.caption.italic())
                    .foregroundStyle(.secondary)
            } else {
                Text("No signing certificates are visible to this API key's role.")
                    .font(.caption.italic())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
