import Foundation
import os
import YcodeDeviceModel

public actor SimulatorDiscoveryPipeline {
    public static let shared = SimulatorDiscoveryPipeline()

    private init() {}

    public func runPipeline(
        onStageChange: @escaping @Sendable (DiscoveryStage) -> Void
    ) async throws -> SimulatorSnapshot {
        let startTime = Date()
        Logger.discovery.info("[PIPELINE] Beginning 10-stage discovery pipeline...")

        onStageChange(.initializing)
        try await checkCancellation()

        onStageChange(.detectingDeveloperDirectory)
        let envProbe = await DeveloperEnvironmentProbe.shared.runProbe()
        try await checkCancellation()

        if envProbe.developerDirectory == "Unavailable" {
            throw SimulatorDiscoveryError(
                stage: .detectingDeveloperDirectory,
                underlyingMessage: "xcode-select developer directory could not be resolved."
            )
        }

        onStageChange(.verifyingXcode)
        try await checkCancellation()
        if envProbe.isCLTOnly {
            Logger.discovery.warning("[PIPELINE] Active toolchain is Command Line Tools only. This is degraded but not fatal.")
        }

        onStageChange(.verifyingXcrun)
        try await checkCancellation()
        if envProbe.xcrunVersion == nil {
            throw SimulatorDiscoveryError(
                stage: .verifyingXcrun,
                underlyingMessage: "xcrun executable is missing from active developer path."
            )
        }

        onStageChange(.verifyingSimctl)
        try await checkCancellation()
        let simctlCheckSpec = CommandSpec(
            executableURL: URL(fileURLWithPath: "/usr/bin/xcrun"),
            arguments: ["simctl", "help"]
        )
        let simctlCheckRecord = await CommandExecutionEngine.shared.execute(simctlCheckSpec)
        if simctlCheckRecord.exitCode != 0 {
            throw SimulatorDiscoveryError(
                stage: .verifyingSimctl,
                underlyingMessage: "simctl utility is present but returned exit code \(simctlCheckRecord.exitCode): \(simctlCheckRecord.stderrString)"
            )
        }

        onStageChange(.discoveringRuntimes)
        onStageChange(.discoveringDevices)
        onStageChange(.discoveringDeviceTypes)

        let discoveryDataResult: SimctlDiscoveryResult
        do {
            discoveryDataResult = try await SimctlDiscoveryClient.shared.fetchDiscoveryData()
        } catch {
            throw SimulatorDiscoveryError(
                stage: .discoveringRuntimes,
                underlyingMessage: "simctl metadata fetch failed: \(error.localizedDescription)"
            )
        }
        try await checkCancellation()

        onStageChange(.mergingAndPublishing)
        let resolvedSnapshot = try mergeAndResolve(discoveryDataResult, startTime: startTime)
        try await checkCancellation()

        onStageChange(.complete)
        Logger.discovery.info("[PIPELINE] 10-stage discovery pipeline completed successfully in \(Date().timeIntervalSince(startTime))s")

        return resolvedSnapshot
    }

    private func checkCancellation() async throws {
        if Task.isCancelled {
            Logger.discovery.warning("[PIPELINE] Task cancellation detected mid-pipeline.")
            throw CancellationError()
        }
    }

    private func mergeAndResolve(_ result: SimctlDiscoveryResult, startTime: Date) throws -> SimulatorSnapshot {
        var domainRuntimes: [SimulatorRuntime] = []
        for r in result.runtimes {
            let platform = DevicePlatform(parsing: r.platform).rawValue
            let resolvedPlatform: String
            if platform == DevicePlatform.unknown.rawValue {
                let fromName = DevicePlatform(parsing: r.name)
                resolvedPlatform = fromName == .unknown ? DevicePlatform(runtimeIdentifier: r.identifier).rawValue : fromName.rawValue
            } else {
                resolvedPlatform = platform
            }
            domainRuntimes.append(SimulatorRuntime(
                identifier: r.identifier,
                name: r.name,
                version: r.version,
                platform: resolvedPlatform,
                isAvailable: r.isAvailable
            ))
        }

        domainRuntimes.sort { r1, r2 in
            r1.version.compare(r2.version, options: .numeric) == .orderedDescending
        }

        var runtimesByID: [String: RuntimeDTO] = [:]
        for r in result.runtimes { runtimesByID[r.identifier] = r }

        var domainDevices: [SimulatorDevice] = []
        var bootedDeviceIDs = Set<String>()

        for (runtimeID, list) in result.devices {
            let runtime = runtimesByID[runtimeID]
            let platform = DevicePlatform(runtimeIdentifier: runtimeID).rawValue
            let cleanRuntimeID = runtimeID.replacingOccurrences(of: "com.apple.CoreSimulator.SimRuntime.", with: "")
            let parts = cleanRuntimeID.split(separator: "-")
            let osVersion = runtime?.version ?? parts.dropFirst().joined(separator: ".")
            let architecture = runtime?.supportedArchitectures?.first ?? "Unknown"

            for d in list {
                let state: SimulatorState = {
                    switch d.state.lowercased() {
                    case "booted": return .booted
                    case "booting": return .booting
                    case "shutting down": return .shuttingDown
                    case "shutdown": return .shutdown
                    default: return .unknown
                    }
                }()

                if state == .booted {
                    bootedDeviceIDs.insert(d.udid)
                }

                domainDevices.append(SimulatorDevice(
                    udid: d.udid,
                    name: d.name,
                    runtimeIdentifier: runtimeID,
                    platform: platform,
                    osVersion: osVersion,
                    architecture: architecture,
                    state: state,
                    isAvailable: d.isAvailable
                ))
            }
        }

        let duration = Duration.seconds(Date().timeIntervalSince(startTime))

        return SimulatorSnapshot(
            runtimes: domainRuntimes,
            devices: domainDevices,
            bootedDeviceIDs: bootedDeviceIDs,
            generatedAt: Date(),
            discoveryDuration: duration
        )
    }
}
