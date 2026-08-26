import SwiftUI

struct SwiftCodeConnectMainView: View {
    @StateObject private var connectionManager = ConnectConnectionManager.shared
    @StateObject private var discovery = BonjourDiscovery.shared
    @StateObject private var trustStore = ConnectTrustStore.shared
    @StateObject private var pairingSession = PairingSession()

    @State private var pairingCodeInput = ""
    @State private var selectedMacForPairing: DiscoveredMacDevice?
    @State private var showPairingDialog = false
    @State private var showPermissionsForMac: PairedMacDevice?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.07, blue: 0.12),
                    Color(red: 0.10, green: 0.10, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    connectionStatusHeaderCard

                    if case .connected = connectionManager.connectionState {
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

                    nearbyMacsSection

                    pairedMacsSection
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
        }
        .sheet(item: $selectedMacForPairing) { mac in
            pairingSheet(for: mac)
        }
        .sheet(item: $showPermissionsForMac) { mac in
            MacPermissionsView(mac: mac)
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

    private var statusCircleColor: Color {
        switch connectionManager.connectionState {
        case .connected: return .green
        case .connecting, .authenticating, .pairing: return .orange
        case .searching, .reconnecting: return .blue
        case .failed: return .red
        case .disconnected: return .gray
        }
    }

    private var accessibleStatusLabel: String {
        switch connectionManager.connectionState {
        case .connected(let mac): return "Connected & Authenticated to \(mac.name)"
        case .connecting: return "Establishing Secure Socket Connection"
        case .authenticating: return "Verifying Cryptographic Credentials"
        case .pairing: return "Exchanging Pairing Verification Code"
        case .searching: return "Scanning Local Network via Bonjour"
        case .reconnecting: return "Attempting Auto-Reconnection"
        case .failed(let err): return "Error: \(err)"
        case .disconnected: return "No active connection"
        }
    }

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
                                Text("\(mac.hostName):\(mac.port)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()

                            if trustStore.isPaired(macID: mac.id) {
                                Text("Paired")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.green)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(.green.opacity(0.15), in: Capsule())
                            } else {
                                Button("Pair Mac") {
                                    pairingCodeInput = pairingSession.generatePairingCode()
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
                                Text("Paired \(mac.datePaired.formatted(date: .abbreviated, time: .omitted))")
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

                            if connectionManager.activeConnectedMac?.id == mac.id {
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

    private func pairingSheet(for mac: DiscoveredMacDevice) -> some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.cyan)

                Text("Pair with \(mac.name)")
                    .font(.title2).bold()
                    .foregroundStyle(.white)

                Text("Enter this 6-digit verification code on your SwiftCode macOS application to approve the connection request:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text(pairingCodeInput)
                    .font(.system(size: 38, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.cyan.opacity(0.4), lineWidth: 1)
                    )

                if case .pairing = pairingSession.state {
                    ProgressView("Exchanging secure keys...")
                        .tint(.cyan)
                }

                if case .failed(let err) = pairingSession.state {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Spacer()

                Button("Start Pairing Handshake") {
                    Task {
                        await pairingSession.pair(with: mac, pairingCode: pairingCodeInput)
                        if case .success = pairingSession.state {
                            selectedMacForPairing = nil
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                .frame(maxWidth: .infinity)
            }
            .padding(24)
            .navigationTitle("Pairing Security")
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
}
