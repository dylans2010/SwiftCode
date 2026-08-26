import SwiftUI
import Network

struct SwiftCodeConnectMainView: View {
    @StateObject private var connectionManager = ConnectConnectionManager.shared
    @StateObject private var discovery = BonjourDiscovery.shared
    @StateObject private var trustStore = ConnectTrustStore.shared
    @StateObject private var localListener = ConnectLocalListener.shared
    @StateObject private var configManager = ConnectConfigurationManager.shared
    @StateObject private var pairingSession = PairingSession.shared

    @State private var selectedMacForPairing: DiscoveredMacDevice?
    @State private var showPermissionsForMac: PairedMacDevice?

    // Port Configuration Sheet State
    @State private var showChangePortSheet = false
    @State private var newPortInput = ""
    @State private var isChangingPort = false
    @State private var portChangeErrorMessage: String?

    // Manual Connection Sheet State
    @State private var showManualConnectSheet = false
    @State private var manualHostInput = ""
    @State private var manualPortInput = ""

    // Diagnostics State
    @State private var showDiagnostics = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.06, blue: 0.11),
                    Color(red: 0.08, green: 0.09, blue: 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    connectionStatusHeaderCard

                    if case .connected = connectionManager.connectionState {
                        dashboardShortcutCard
                    }

                    if let error = connectionManager.lastErrorMessage {
                        actionableErrorCard(message: error)
                    }

                    portConfigurationCard

                    nearbyMacsSection

                    pairedMacsSection

                    manualConnectionCard

                    diagnosticsSection
                }
                .padding()
            }
        }
        .navigationTitle("SwiftCode Connect")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if discovery.isSearching {
                        discovery.stopDiscovery()
                    } else {
                        discovery.startDiscovery()
                    }
                } label: {
                    Label(discovery.isSearching ? "Stop Scan" : "Scan", systemImage: discovery.isSearching ? "stop.circle" : "arrow.triangle.2.circlepath")
                }
            }
        }
        .onAppear {
            discovery.startDiscovery()
            manualHostInput = configManager.configuration.manualHost
            manualPortInput = String(configManager.configuration.manualPort)
        }
        .sheet(item: $selectedMacForPairing) { mac in
            pairingSheet(for: mac)
        }
        .sheet(item: $showPermissionsForMac) { mac in
            MacPermissionsView(mac: mac)
        }
        .sheet(isPresented: $showChangePortSheet) {
            changePortSheet
        }
        .sheet(isPresented: $showManualConnectSheet) {
            manualConnectSheet
        }
    }

    // MARK: - Subviews

    private var connectionStatusHeaderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(statusCircleColor)
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(connectionManager.connectionState.statusDescription)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(accessibleStatusLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                if connectionManager.connectionState.isConnected {
                    Button("Disconnect") {
                        connectionManager.disconnect()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.small)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(statusCircleColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var dashboardShortcutCard: some View {
        NavigationLink {
            ConnectedMacDashboardView()
        } label: {
            HStack {
                Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                    .font(.title2)
                    .foregroundStyle(.cyan)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Open Connected Mac Dashboard")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Monitor project, trigger builds, and view live logs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func actionableErrorCard(message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text("Connection Diagnostic")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Port Configuration Section

    private var portConfigurationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundStyle(.cyan)
                Text("Network Configuration")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Button("Change Port") {
                    newPortInput = String(configManager.configuration.port)
                    portChangeErrorMessage = nil
                    showChangePortSheet = true
                }
                .buttonStyle(.bordered)
                .tint(.cyan)
                .controlSize(.small)
            }

            Text("The port SwiftCode Connect uses for local network communication and socket listener.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider().overlay(.white.opacity(0.1))

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connection Port")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                    Text("Authoritative local socket binding")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Circle()
                        .fill(localListener.isListening ? .green : .orange)
                        .frame(width: 8, height: 8)
                    Text("\(configManager.configuration.port)")
                        .font(.system(.body, design: .monospaced).weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }
            }

            HStack {
                Text("Listener Status:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(localListener.status.statusDescription)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(localListener.isListening ? .green : (localListener.errorMessage != nil ? .red : .orange))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Nearby Macs Section

    private var nearbyMacsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Nearby Macs")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                if discovery.isSearching {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.cyan)
                }
            }

            if discovery.discoveredDevices.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "desktopcomputer.search")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No SwiftCode macOS instances found on local network.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            } else {
                VStack(spacing: 10) {
                    ForEach(discovery.discoveredDevices) { mac in
                        HStack {
                            Image(systemName: "desktopcomputer")
                                .font(.title3)
                                .foregroundStyle(.cyan)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(mac.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text("SwiftCode Mac • \(mac.formattedEndpoint)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()

                            if trustStore.isPaired(macID: mac.name) || trustStore.pairedMacs.contains(where: { $0.name == mac.name }) {
                                Button("Connect") {
                                    if let paired = trustStore.pairedMacs.first(where: { $0.name == mac.name }) {
                                        var updated = paired
                                        updated.hostName = mac.hostName
                                        updated.port = mac.port
                                        connectionManager.connect(to: updated)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.blue)
                                .controlSize(.small)
                            } else {
                                Button("Pair") {
                                    selectedMacForPairing = mac
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.cyan)
                                .controlSize(.small)
                            }
                        }
                        .padding(12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    // MARK: - Paired Macs Section

    private var pairedMacsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Paired Macs")
                .font(.headline)
                .foregroundStyle(.white)

            if trustStore.pairedMacs.isEmpty {
                Text("No paired Mac computers registered.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            } else {
                VStack(spacing: 10) {
                    ForEach(trustStore.pairedMacs) { mac in
                        HStack {
                            Image(systemName: "desktopcomputer.trianglebadge.exclamationmark")
                                .font(.title3)
                                .foregroundStyle(.green)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(mac.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text("\(mac.hostName):\(mac.port) • Paired \(mac.datePaired.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()

                            Button {
                                showPermissionsForMac = mac
                            } label: {
                                Image(systemName: "slider.horizontal.3")
                                    .foregroundStyle(.secondary)
                            }

                            if connectionManager.activeConnectedMac?.id == mac.id && connectionManager.connectionState.isConnected {
                                Text("Connected")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.green)
                            } else {
                                Button("Connect") {
                                    connectionManager.connect(to: mac)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.blue)
                                .controlSize(.small)
                            }
                        }
                        .padding(12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .contextMenu {
                            Button(role: .destructive) {
                                trustStore.removePairedMac(macID: mac.id)
                            } label: {
                                Label("Forget Mac", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Manual Connection Fallback Card

    private var manualConnectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "network")
                    .foregroundStyle(.cyan)
                Text("Manual Endpoint Connection")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Button("Connect Manually") {
                    showManualConnectSheet = true
                }
                .buttonStyle(.bordered)
                .tint(.cyan)
                .controlSize(.small)
            }

            Text("Connect directly by IP address and port if Bonjour multicast discovery is filtered on your local Wi-Fi.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Developer Diagnostics Section

    private var diagnosticsSection: some View {
        DisclosureGroup(isExpanded: $showDiagnostics) {
            VStack(spacing: 8) {
                diagnosticRow(title: "Local Address", value: getLocalIPAddress() ?? "127.0.0.1")
                diagnosticRow(title: "Local Port", value: "\(configManager.configuration.port)")
                diagnosticRow(title: "Listening", value: localListener.isListening ? "Yes (Bound)" : "No")
                diagnosticRow(title: "Bonjour Service", value: localListener.isAdvertising ? "Advertising (_swiftcodeconnect._tcp)" : "Idle")
                Divider().overlay(.white.opacity(0.1))
                diagnosticRow(title: "Remote Device", value: connectionManager.activeConnectedMac?.name ?? "None")
                diagnosticRow(title: "Remote Address", value: connectionManager.activeConnectedMac?.hostName ?? "None")
                diagnosticRow(title: "Remote Port", value: connectionManager.activeConnectedMac != nil ? "\(connectionManager.activeConnectedMac!.port)" : "None")
                diagnosticRow(title: "Transport", value: "Framed TCP (4-byte length prefix)")
                diagnosticRow(title: "Authentication", value: connectionManager.connectionState.isConnected ? "Authenticated (Bearer Token)" : "Unauthenticated")
                diagnosticRow(title: "Protocol Version", value: "v\(ConnectProtocolVersion.current)")
                diagnosticRow(title: "Session State", value: connectionManager.connectionState.statusDescription)
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Image(systemName: "wrench.and.screwdriver")
                    .foregroundStyle(.secondary)
                Text("SwiftCode Connect Diagnostics")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private func diagnosticRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Sheets

    private var changePortSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "slider.horizontal.2.square")
                    .font(.system(size: 48))
                    .foregroundStyle(.cyan)
                    .padding(.top, 10)

                Text("Configure Connection Port")
                    .font(.title3).bold()
                    .foregroundStyle(.white)

                Text("Enter a valid TCP port number between 1024 and 65535. Changing the port will restart the local listener and re-advertise the new endpoint via Bonjour.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                TextField("Port (e.g. 8088)", text: $newPortInput)
                    .keyboardType(.numberPad)
                    .font(.system(.title2, design: .monospaced).bold())
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                    )

                if isChangingPort {
                    VStack(spacing: 8) {
                        ProgressView()
                            .tint(.cyan)
                        Text(localListener.status.statusDescription)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.cyan)
                    }
                    .padding(.vertical, 8)
                }

                if let err = portChangeErrorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                Button("Apply & Restart Listener") {
                    guard let port = SwiftCodeConnectConfiguration.validatePortString(newPortInput) else {
                        portChangeErrorMessage = "Port is invalid. Please choose a number between 1024 and 65535."
                        return
                    }

                    isChangingPort = true
                    portChangeErrorMessage = nil

                    Task {
                        let success = await localListener.changePort(to: port)
                        isChangingPort = false
                        if success {
                            showChangePortSheet = false
                        } else {
                            portChangeErrorMessage = localListener.errorMessage ?? "Port unavailable. Choose another port."
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                .disabled(isChangingPort)
                .frame(maxWidth: .infinity)
            }
            .padding(24)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showChangePortSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var manualConnectSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "network.badge.shield.half.filled")
                    .font(.system(size: 48))
                    .foregroundStyle(.cyan)
                    .padding(.top, 10)

                Text("Connect Manually")
                    .font(.title3).bold()
                    .foregroundStyle(.white)

                Text("Enter the IP address or local hostname of your Mac and the SwiftCode Connect listening port.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Host / IP Address")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("e.g. 192.168.1.25", text: $manualHostInput)
                        .font(.body)
                        .padding()
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Port")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("e.g. 8088", text: $manualPortInput)
                        .keyboardType(.numberPad)
                        .font(.body)
                        .padding()
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }

                Spacer()

                Button("Connect") {
                    guard let port = SwiftCodeConnectConfiguration.validatePortString(manualPortInput),
                          !manualHostInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        return
                    }
                    showManualConnectSheet = false
                    connectionManager.connectManually(host: manualHostInput, port: port)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                .frame(maxWidth: .infinity)
            }
            .padding(24)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showManualConnectSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func pairingSheet(for mac: DiscoveredMacDevice) -> some View {
        let code = pairingSession.currentPairingCode.isEmpty ? pairingSession.generatePairingCode() : pairingSession.currentPairingCode

        return NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.cyan)

                Text("Pairing Request")
                    .font(.title2).bold()
                    .foregroundStyle(.white)

                Text("Verify this 6-digit code matches the prompt on \(mac.name):")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text(code)
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.cyan.opacity(0.4), lineWidth: 1)
                    )

                if case .pairing = pairingSession.state {
                    ProgressView("Authenticating with Mac…")
                        .tint(.cyan)
                }

                if case .failed(let err) = pairingSession.state {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Spacer()

                Button("Pair") {
                    Task {
                        await pairingSession.pair(with: mac, pairingCode: code)
                        if case .success(let paired) = pairingSession.state {
                            selectedMacForPairing = nil
                            connectionManager.connect(to: paired)
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                .frame(maxWidth: .infinity)
            }
            .padding(24)
            .navigationTitle("Connect to Mac")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        pairingSession.cancel()
                        selectedMacForPairing = nil
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Helpers

    private var statusCircleColor: Color {
        switch connectionManager.connectionState {
        case .connected: return .green
        case .connecting, .transportConnected, .handshaking, .authenticating, .pairing, .synchronizing: return .orange
        case .discovering, .reconnecting: return .blue
        case .connectionFailed, .authenticationFailed, .protocolMismatch, .portUnavailable, .hostUnavailable, .permissionDenied: return .red
        case .idle, .discovered: return .gray
        }
    }

    private var accessibleStatusLabel: String {
        switch connectionManager.connectionState {
        case .connected(let mac): return "Connected & Authenticated to \(mac.name)"
        case .connecting(let endpoint): return "Connecting to socket at \(endpoint)"
        case .transportConnected: return "Socket transport established"
        case .handshaking: return "Exchanging protocol metadata"
        case .authenticating: return "Verifying cryptographic session token"
        case .pairing: return "Exchanging 6-digit pairing code"
        case .synchronizing: return "Synchronizing workspace & git status"
        case .discovering: return "Scanning local network via Bonjour"
        case .reconnecting(let n): return "Attempting reconnection (retry \(n)/5)"
        case .connectionFailed(let err): return "Error: \(err)"
        case .authenticationFailed(let err): return "Auth error: \(err)"
        case .protocolMismatch(let err): return "Protocol error: \(err)"
        case .portUnavailable(let err): return "Port error: \(err)"
        case .hostUnavailable(let err): return "Host error: \(err)"
        case .permissionDenied(let err): return "Permission error: \(err)"
        case .idle: return "No active connection"
        case .discovered(let mac): return "Found \(mac.name)"
        }
    }

    private func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            let addr = ptr.pointee.ifa_addr.pointee

            if (flags & (IFF_UP | IFF_RUNNING | IFF_LOOPBACK)) == (IFF_UP | IFF_RUNNING) {
                if addr.sa_family == UInt8(AF_INET) {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(ptr.pointee.ifa_addr, socklen_t(MemoryLayout<sockaddr_in>.size), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                        let ip = String(cString: hostname)
                        if ip != "127.0.0.1" {
                            address = ip
                            break
                        }
                    }
                }
            }
        }
        return address
    }
}
