import AppKit
import Foundation
import SwiftUI
import YcodeDeviceModel
import YcodeIDECore
import YcodeSubprocess

@MainActor
public final class DeviceHubSimulatorInstaller: ObservableObject {
    public static let shared = DeviceHubSimulatorInstaller()

    @Published public var isRunning = false
    @Published public var currentPlatform: SimPlatform = .iOS
    @Published public var progressFraction: Double?
    @Published public var progressStage: String = "Idle"
    @Published public var progressLine: String = ""
    @Published public var logLines: [String] = []
    @Published public var errorMessage: String?
    @Published public var availableDeviceTypes: [(name: String, identifier: String)] = []
    @Published public var availableRuntimes: [(name: String, identifier: String)] = []

    private var currentRun: XcodebuildDownloadRun?

    public init() {}

    public func fetchAvailableTypesAndRuntimes() {
        Task {
            let types = await Self.fetchDeviceTypes()
            let runtimes = await Self.fetchRuntimes()
            await MainActor.run {
                self.availableDeviceTypes = types
                self.availableRuntimes = runtimes
            }
        }
    }

    public func installPlatform(_ platform: SimPlatform, onFinished: (@MainActor (Bool) -> Void)? = nil) {
        guard !isRunning else { return }
        isRunning = true
        currentPlatform = platform
        progressFraction = nil
        progressStage = "Starting download for \(platform.title)…"
        progressLine = "Initializing Xcode tools…"
        logLines.removeAll()
        errorMessage = nil

        let download = XcodebuildDownload(platform: platform)
        let run = XcodebuildDownloadRun(download)
        currentRun = run

        Task {
            let outcome = await run.run(
                output: { [weak self] line in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.logLines.append(line)
                        if self.logLines.count > 1000 { self.logLines.removeFirst(200) }
                    }
                },
                progress: { [weak self] p in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        if let f = p.fraction { self.progressFraction = f }
                        if let s = p.stage { self.progressStage = s }
                        self.progressLine = p.line
                    }
                }
            )

            await MainActor.run {
                self.isRunning = false
                self.currentRun = nil
                switch outcome {
                case .finished:
                    self.progressStage = "Completed successfully!"
                    self.progressFraction = 1.0
                    onFinished?(true)
                case .cancelled:
                    self.progressStage = "Cancelled"
                    onFinished?(false)
                case .failed(let code, let err):
                    self.progressStage = "Failed (Exit code \(code))"
                    self.errorMessage = err
                    onFinished?(false)
                }
            }
        }
    }

    public func cancel() {
        currentRun?.cancel()
    }

    public static func fetchDeviceTypes() async -> [(name: String, identifier: String)] {
        await Task.detached {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            p.arguments = ["simctl", "list", "-j", "devicetypes"]
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = FileHandle.nullDevice
            guard (try? p.run()) != nil else { return [] }
            p.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let list = json["devicetypes"] as? [[String: Any]] else { return [] }
            return list.compactMap { dict in
                guard let name = dict["name"] as? String,
                      let id = dict["identifier"] as? String else { return nil }
                return (name: name, identifier: id)
            }
        }.value
    }

    public static func fetchRuntimes() async -> [(name: String, identifier: String)] {
        await Task.detached {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            p.arguments = ["simctl", "list", "-j", "runtimes"]
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = FileHandle.nullDevice
            guard (try? p.run()) != nil else { return [] }
            p.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let list = json["runtimes"] as? [[String: Any]] else { return [] }
            return list.compactMap { dict in
                guard let name = dict["name"] as? String,
                      let id = dict["identifier"] as? String else { return nil }
                return (name: name, identifier: id)
            }
        }.value
    }

    public static func createSimulator(name: String, deviceTypeID: String, runtimeID: String) async throws -> String {
        try await Task.detached {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            p.arguments = ["simctl", "create", name, deviceTypeID, runtimeID]
            let outPipe = Pipe()
            let errPipe = Pipe()
            p.standardOutput = outPipe
            p.standardError = errPipe
            try p.run()
            p.waitUntilExit()
            let outStr = String(decoding: outPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            if p.terminationStatus != 0 {
                let errStr = String(decoding: errPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                throw NSError(domain: "SimulatorInstaller", code: Int(p.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errStr.isEmpty ? "Failed to create simulator" : errStr])
            }
            return outStr
        }.value
    }
}

public struct InstallSimulatorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var installer = DeviceHubSimulatorInstaller.shared
    @State private var selectedPlatform: SimPlatform = .iOS
    let onCompletion: (() -> Void)?

    public init(onCompletion: (() -> Void)? = nil) {
        self.onCompletion = onCompletion
    }

    public var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Install Simulator Runtimes")
                        .font(.headline)
                    Text("Download and install official Apple Simulator platforms via Xcode tooling")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Select Platform")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Picker("Platform", selection: $selectedPlatform) {
                    ForEach(SimPlatform.allCases, id: \.self) { platform in
                        Text(platform.title).tag(platform)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(installer.isRunning)

                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    Text("Invokes `xcodebuild -downloadPlatform \(selectedPlatform.downloadName)` directly with background Process execution.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)

            if installer.isRunning || installer.progressFraction != nil {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(installer.progressStage)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        if let f = installer.progressFraction {
                            Text("\(Int(f * 100))%")
                                .font(.monospacedDigit(.subheadline)())
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let f = installer.progressFraction {
                        ProgressView(value: f)
                            .progressViewStyle(.linear)
                    } else {
                        ProgressView()
                            .progressViewStyle(.linear)
                    }

                    Text(installer.progressLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.horizontal)
            }

            if let error = installer.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .padding(.horizontal)
            }

            if !installer.logLines.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Execution Output")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(installer.logLines.suffix(20).enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(6)
                    }
                    .frame(height: 100)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)
                }
                .padding(.horizontal)
            }

            Spacer()

            HStack {
                if installer.isRunning {
                    Button("Cancel") {
                        installer.cancel()
                    }
                } else {
                    Button("Close") {
                        dismiss()
                    }
                }

                Spacer()

                Button(installer.isRunning ? "Downloading…" : "Install Runtime") {
                    installer.installPlatform(selectedPlatform) { success in
                        if success {
                            onCompletion?()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(installer.isRunning)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 520, height: 420)
    }
}

public struct CreateSimulatorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var installer = DeviceHubSimulatorInstaller.shared
    @State private var simulatorName = ""
    @State private var selectedDeviceType = ""
    @State private var selectedRuntime = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    let onCreated: ((String) -> Void)?

    public init(onCreated: ((String) -> Void)? = nil) {
        self.onCreated = onCreated
    }

    public var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Create Simulator")
                        .font(.headline)
                    Text("Create a new simulator instance with Apple's `simctl` tool")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Simulator Name")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    TextField("e.g. iPhone 17 Pro Max (Development)", text: $simulatorName)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Device Type")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Picker("", selection: $selectedDeviceType) {
                        if installer.availableDeviceTypes.isEmpty {
                            Text("Loading device types…").tag("")
                        }
                        ForEach(installer.availableDeviceTypes, id: \.identifier) { dt in
                            Text(dt.name).tag(dt.identifier)
                        }
                    }
                    .pickerStyle(.menu)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Runtime")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Picker("", selection: $selectedRuntime) {
                        if installer.availableRuntimes.isEmpty {
                            Text("Default / Latest Installed Runtime").tag("")
                        }
                        ForEach(installer.availableRuntimes, id: \.identifier) { r in
                            Text(r.name).tag(r.identifier)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if let err = errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal)

            Spacer()

            HStack {
                Button("Cancel") {
                    dismiss()
                }

                Spacer()

                Button(isCreating ? "Creating…" : "Create Simulator") {
                    create()
                }
                .buttonStyle(.borderedProminent)
                .disabled(simulatorName.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 480, height: 350)
        .onAppear {
            installer.fetchAvailableTypesAndRuntimes()
            if let firstType = installer.availableDeviceTypes.first?.identifier {
                selectedDeviceType = firstType
            }
        }
        .onChange(of: installer.availableDeviceTypes.count) { _ in
            if selectedDeviceType.isEmpty, let first = installer.availableDeviceTypes.first?.identifier {
                selectedDeviceType = first
            }
        }
    }

    private func create() {
        guard !simulatorName.isEmpty else { return }
        isCreating = true
        errorMessage = nil

        let typeID = selectedDeviceType.isEmpty ? (installer.availableDeviceTypes.first?.identifier ?? "iPhone 17") : selectedDeviceType
        let runID = selectedRuntime.isEmpty ? (installer.availableRuntimes.first?.identifier ?? "iOS") : selectedRuntime

        Task {
            do {
                let udid = try await DeviceHubSimulatorInstaller.createSimulator(name: simulatorName, deviceTypeID: typeID, runtimeID: runID)
                await MainActor.run {
                    self.isCreating = false
                    self.onCreated?(udid)
                    self.dismiss()
                }
            } catch {
                await MainActor.run {
                    self.isCreating = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
