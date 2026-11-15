import Foundation
import Testing
@testable import YcodeDeviceModel

@Suite struct DeviceConnectTests {
    @Test func buildParserSplitsErrorsAndWarnings() {
        let text = """
        /Users/dylan/App.swift:12:7: error: cannot find 'Foo' in scope
        /Users/dylan/App.swift:20:3: warning: unused variable 'bar'
        note: some other line
        """
        let result = BuildParser.parseXcodebuildOutput(text)
        #expect(result.errors.count == 1)
        #expect(result.errors[0].filePath == "/Users/dylan/App.swift")
        #expect(result.errors[0].line == 12)
        #expect(result.errors[0].message == "cannot find 'Foo' in scope")
        #expect(result.errors[0].isError)
        #expect(result.warnings.count == 1)
        #expect(result.warnings[0].line == 20)
        #expect(!result.warnings[0].isError)
    }

    @Test func deviceParserDecodesXCDeviceList() {
        let json = """
        [
          {"name": "Dylan's iPhone", "model": "iPhone 17 Pro", "platform": "iOS",
           "operatingSystemVersion": "26.1", "identifier": "00008110-1111111111111111",
           "modelUTI": "com.apple.iphone-17-pro", "isWirelesslyConnected": false,
           "isConnected": true, "isAvailable": true},
          {"name": "Nameless", "identifier": null},
          {"name": "Old iPad", "model": "iPad", "platform": "iPadOS",
           "operatingSystemVersion": "26.0", "identifier": "00008110-2222222222222222"}
        ]
        """
        let devices = DeviceParser.parseXCDeviceList(json)
        #expect(devices.count == 2)
        #expect(devices[0].name == "Dylan's iPhone")
        #expect(devices[0].udid == "00008110-1111111111111111")
        #expect(devices[0].osVersion == "26.1")
        #expect(devices[1].platform == "iPadOS")
    }

    @Test func deviceParserReturnsEmptyForGarbage() {
        #expect(DeviceParser.parseXCDeviceList("not json").isEmpty)
        #expect(DeviceParser.parseXCDeviceList("").isEmpty)
    }

    @Test func logParserClassifiesSeverity() {
        #expect(LogParser.parseLogLine("[error] boom", type: .runtime).severity == .error)
        #expect(LogParser.parseLogLine("warning: low memory", type: .runtime).severity == .warning)
        #expect(LogParser.parseLogLine("[debug] tick", type: .runtime).severity == .debug)
        #expect(LogParser.parseLogLine("all good", type: .build).severity == .info)
        #expect(LogParser.parseLogLine("[MySubsystem] hello", type: .build).category == "MySubsystem")
    }

    @Test func outputFormatterStripsANSIAndFormatsBytes() {
        #expect(OutputFormatter.stripANSIColorCodes("\u{1B}[31mred\u{1B}[0m") == "red")
        #expect(OutputFormatter.formatBytes(500) == "0 KB")
        #expect(OutputFormatter.formatBytes(2_048) == "2 KB")
        #expect(OutputFormatter.formatBytes(3 * 1024 * 1024) == "3.0 MB")
        #expect(OutputFormatter.formatBytes(2.5 * 1024 * 1024 * 1024) == "2.50 GB")
    }

    @Test func diagnosticsFormatterReportsMissingXcode() {
        let env = DeviceEnvironment(macOSVersion: "26.1")
        let diagnostics = DiagnosticsFormatter.formatEnvironmentDiagnostics(env)
        #expect(diagnostics.contains { $0.contains("Xcode is not detected") })
        #expect(diagnostics.contains { $0.contains("iOS SDK") })
    }

    @Test func diagnosticsFormatterPassesCleanEnvironment() {
        let env = DeviceEnvironment(
            xcodePath: "/Applications/Xcode.app",
            xcodeVersion: "27.1",
            macOSVersion: "26.1",
            hasiOSSDK: true,
            hasSimulatorSDK: true,
            isSigningSetup: true)
        #expect(DiagnosticsFormatter.formatEnvironmentDiagnostics(env) == ["All checks passed. System is fully compatible with DeviceConnect deployment pipelines."])
    }

    @Test func deviceMetricsUnavailableIsMarked() {
        #expect(!DeviceMetrics.unavailable.isAvailable)
        #expect(DeviceMetrics().isAvailable)
    }

    @Test func deviceMetricsUnavailableCarriesReason() {
        #expect(DeviceMetrics.unavailable.unavailableReason != nil)
        #expect(DeviceMetrics.unavailable(reason: "test reason").unavailableReason == "test reason")
        #expect(!DeviceMetrics.unavailable(reason: "test reason").isAvailable)
        #expect(DeviceMetrics().unavailableReason == nil)
    }

    @Test func simulatorDefaultsValueParsesBoolOutput() {
        #expect(SimulatorDefaultsValue.parseBool("1\n") == true)
        #expect(SimulatorDefaultsValue.parseBool("0") == false)
        #expect(SimulatorDefaultsValue.parseBool("true") == true)
        #expect(SimulatorDefaultsValue.parseBool("false") == false)
        #expect(SimulatorDefaultsValue.parseBool("yes") == true)
        #expect(SimulatorDefaultsValue.parseBool("no") == false)
        #expect(SimulatorDefaultsValue.parseBool("") == nil)
        #expect(SimulatorDefaultsValue.parseBool("2") == nil)
        #expect(SimulatorDefaultsValue.parseBool("unknown") == nil)
    }

    @Test func processRunnerCapturesEchoOutput() async throws {
        let result = try await DeviceConnectProcessRunner.shared.run(
            executableURL: URL(fileURLWithPath: "/bin/echo"),
            arguments: ["hello", "device"])
        #expect(result.exitCode == 0)
        #expect(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "hello device")
    }

    @Test func processRunnerThrowsForMissingExecutable() async {
        await #expect(throws: DeviceConnectProcessError.self) {
            try await DeviceConnectProcessRunner.shared.run(
                executableURL: URL(fileURLWithPath: "/bin/definitely-not-a-real-tool"),
                arguments: [])
        }
    }

    @Test func processRunnerStreamsLinesLive() async throws {
        let box = LineBox()
        let success = try await DeviceConnectProcessRunner.shared.runStreamingAsync(
            executableURL: URL(fileURLWithPath: "/bin/echo"),
            arguments: ["streamed"],
            onStdout: { line in box.append(line) },
            onStderr: { _ in })
        #expect(success)
        #expect(box.lines.contains("streamed"))
    }
}

@Suite(.serialized)
struct DeviceConnectConsoleTests {
    @Test @MainActor func consoleFilteringMatchesSearchAndSeverity() {
        let manager = DeviceConnectConsoleManager.shared
        manager.clearAllLogs()
        manager.appendLog(DeviceLog(type: .build, severity: .error, message: "boom failed"))
        manager.appendLog(DeviceLog(type: .build, severity: .warning, message: "careful now"))
        manager.appendLog(DeviceLog(type: .runtime, severity: .info, message: "boom running"))
        #expect(DeviceConnectConsoleManager.filteredLogs(manager.buildLogs, searchText: "boom", severity: nil).count == 1)
        #expect(DeviceConnectConsoleManager.filteredLogs(manager.buildLogs, searchText: "", severity: .warning).count == 1)
        #expect(DeviceConnectConsoleManager.filteredLogs(manager.buildLogs, searchText: "boom", severity: .warning).isEmpty)
        #expect(DeviceConnectConsoleManager.filteredLogs(manager.buildLogs, searchText: "", severity: nil).count == 2)
        #expect(manager.visibleLogs(searchText: "boom", severity: nil).count == 1)
        manager.clearAllLogs()
        #expect(manager.buildLogs.isEmpty)
        #expect(manager.runtimeLogs.isEmpty)
    }

    @Test @MainActor func consolePauseBuffersAndResumeFlushes() {
        let manager = DeviceConnectConsoleManager.shared
        manager.clearAllLogs()
        manager.pause()
        #expect(manager.isPaused)
        manager.appendLog(DeviceLog(type: .runtime, severity: .info, message: "held line"))
        manager.appendLog(DeviceLog(type: .build, severity: .error, message: "held build"))
        #expect(manager.runtimeLogs.isEmpty)
        #expect(manager.buildLogs.isEmpty)
        manager.resume()
        #expect(!manager.isPaused)
        #expect(manager.runtimeLogs.count == 1)
        #expect(manager.runtimeLogs[0].message == "held line")
        #expect(manager.buildLogs.count == 1)
        #expect(manager.buildLogs[0].message == "held build")
        manager.clearAllLogs()
    }

    @Test @MainActor func consoleExportTextFormatsFilteredLines() {
        let logs = [
            DeviceLog(type: .build, severity: .error, message: "boom"),
            DeviceLog(type: .build, severity: .warning, message: "careful"),
            DeviceLog(type: .build, severity: .info, message: "all good"),
        ]
        let text = DeviceConnectConsoleManager.formattedText(logs)
        #expect(text.contains("[error] boom"))
        #expect(text.contains("[warning] careful"))
        #expect(text.contains("[info] all good"))
        #expect(DeviceConnectConsoleManager.formattedText([]).isEmpty)
        #expect(DeviceConnectConsoleManager.formattedText(DeviceConnectConsoleManager.filteredLogs(logs, searchText: "", severity: .error)).contains("boom"))
        #expect(!DeviceConnectConsoleManager.formattedText(DeviceConnectConsoleManager.filteredLogs(logs, searchText: "", severity: .error)).contains("careful"))
    }

    @Test @MainActor func consoleClearRemovesOnlySelectedTab() {
        let manager = DeviceConnectConsoleManager.shared
        manager.clearAllLogs()
        manager.selectedConsoleTab = 0
        manager.appendLog(DeviceLog(type: .build, severity: .info, message: "build line"))
        manager.appendLog(DeviceLog(type: .runtime, severity: .info, message: "runtime line"))
        manager.clearLogs()
        #expect(manager.buildLogs.isEmpty)
        #expect(manager.runtimeLogs.count == 1)
        manager.clearAllLogs()
    }
}

private final class LineBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []
    var lines: [String] { lock.withLock { storage } }
    func append(_ line: String) { lock.withLock { storage.append(line) } }
}
