import Foundation
import Testing
@testable import YcodeAssistant

@Suite(.serialized) struct MetaAssistBridgeTests {

    static func tempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("meta-bridge-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static let fakeMuseScript = """
        #!/usr/bin/env python3
        import sys, json, os
        log_path = os.environ.get("FAKE_MUSE_LOG", "")
        want_approval = os.environ.get("FAKE_MUSE_APPROVAL", "") == "1"
        def log(method):
            if log_path:
                with open(log_path, "a") as f:
                    f.write(method + "\\n")
        def send(obj):
            sys.stdout.write(json.dumps(obj) + "\\n")
            sys.stdout.flush()
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue
            try:
                msg = json.loads(line)
            except Exception:
                continue
            method = msg.get("method", "")
            rid = msg.get("id")
            log(method)
            if method == "initialize":
                send({"jsonrpc": "2.0", "id": rid, "result": {"capabilities": {}}})
            elif method == "model/list":
                send({"jsonrpc": "2.0", "id": rid, "result": {"models": [
                    {"modelId": "muse-wonder-1.0", "displayLabel": "muse-wonder-1.0",
                     "releaseDate": "2026-10-12", "contextLimit": 1007997,
                     "outputLimit": 128000, "isDefault": True,
                     "variants": ["high"], "defaultReasoningEffort": "high"}]}})
            elif method == "session/start":
                send({"jsonrpc": "2.0", "id": rid, "result": {"session": {"sessionId": "sess-1"}}})
            elif method == "session/resume":
                send({"jsonrpc": "2.0", "id": rid, "result": {}})
            elif method == "turn/start":
                send({"jsonrpc": "2.0", "id": rid, "result": {"turnId": "turn-1"}})
                send({"jsonrpc": "2.0", "method": "item/started", "params": {"item": {"itemId": "i-1", "kind": "agentMessage"}}})
                send({"jsonrpc": "2.0", "method": "item/delta", "params": {"itemId": "i-1", "field": "text", "delta": "Hello "}})
                send({"jsonrpc": "2.0", "method": "item/delta", "params": {"itemId": "i-1", "field": "text", "delta": "world"}})
                if want_approval:
                    send({"jsonrpc": "2.0", "method": "approval/requested", "params": {"sessionId": "sess-1", "approvalId": "ap-1", "action": "run tests"}})
                send({"jsonrpc": "2.0", "method": "item/completed", "params": {"item": {"itemId": "i-1", "kind": "agentMessage", "text": "Hello world"}}})
                send({"jsonrpc": "2.0", "method": "turn/completed", "params": {"turnId": "turn-1"}})
            elif method == "turn/cancel":
                send({"jsonrpc": "2.0", "id": rid, "result": {}})
            elif method == "approval/decide":
                send({"jsonrpc": "2.0", "id": rid, "result": {}})
            elif method == "session/setModel":
                send({"jsonrpc": "2.0", "id": rid, "result": {}})
            elif method == "turn/unqueue":
                send({"jsonrpc": "2.0", "id": rid, "result": {}})
            else:
                send({"jsonrpc": "2.0", "id": rid, "error": {"code": -32601, "message": "Method not found: " + method}})
        """

    static let argLogScript = """
        #!/bin/sh
        printf '%s\\n' "$@" > "$MSP_ARGV_LOG"
        printf '%s' "$PATH" > "$MSP_PATH_LOG"
        /bin/cat
        """

    static func installFakeMuse(approval: Bool = false) throws -> (dir: URL, log: URL, script: URL) {
        let dir = try tempDir()
        let script = dir.appendingPathComponent("muse")
        try fakeMuseScript.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        let log = dir.appendingPathComponent("methods.log")
        if approval { _ = setenv("FAKE_MUSE_APPROVAL", "1", 1) }
        _ = setenv("FAKE_MUSE_LOG", log.path, 1)
        _ = setenv("MUSE_PATH", script.path, 1)
        return (dir, log, script)
    }

    static func clearFakeMuseEnv() {
        unsetenv("FAKE_MUSE_APPROVAL")
        unsetenv("FAKE_MUSE_LOG")
        unsetenv("MUSE_PATH")
    }

    static func installArgLogScript() throws -> (dir: URL, script: URL, argvLog: URL, pathLog: URL) {
        let dir = try tempDir()
        let script = dir.appendingPathComponent("muse-args")
        try argLogScript.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        return (dir, script, dir.appendingPathComponent("argv.log"), dir.appendingPathComponent("path.log"))
    }

    static func waitForNonEmptyFile(_ url: URL, timeout: TimeInterval = 5) async -> String? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let s = try? String(contentsOf: url, encoding: .utf8), !s.isEmpty { return s }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return nil
    }

    final class PermissionAskedBox: @unchecked Sendable {
        private let lock = NSLock()
        private var items: [(String, [AgentAttachment.PermissionOption])] = []
        func add(_ title: String, _ options: [AgentAttachment.PermissionOption]) {
            lock.lock(); items.append((title, options)); lock.unlock()
        }
        var all: [(String, [AgentAttachment.PermissionOption])] {
            lock.lock(); defer { lock.unlock() }; return items
        }
    }

    final class ChatEventLog: @unchecked Sendable {
        private let lock = NSLock()
        private var events: [ChatEvent] = []
        func add(_ event: ChatEvent) {
            lock.lock(); events.append(event); lock.unlock()
        }
        var all: [ChatEvent] {
            lock.lock(); defer { lock.unlock() }; return events
        }
        var text: String {
            all.reduce(into: "") { partial, event in
                if case .text(let delta) = event { partial += delta }
            }
        }
    }

    static func pythonAvailable() -> Bool {
        FileManager.default.fileExists(atPath: "/usr/bin/python3")
    }

    @Test func uuidv7ShapeAndVersion() {
        let id = MuseUUIDv7.generate()
        let parts = id.split(separator: "-")
        #expect(parts.count == 5)
        #expect(parts[0].count == 8 && parts[1].count == 4 && parts[2].count == 4 && parts[3].count == 4 && parts[4].count == 12)
        #expect(parts[2].first == "7")
        #expect(["8", "9", "a", "b"].contains(String(parts[3].first!)))
        #expect(MuseUUIDv7.generate() != id)
        // The first 48 bits of a UUIDv7 are the Unix epoch milliseconds.
        let hexPrefix = String(id.prefix(12))
        let ms = UInt64(hexPrefix, radix: 16)
        #expect(ms != nil)
        let now = UInt64(Date().timeIntervalSince1970 * 1000)
        #expect(ms! <= now && now - ms! < 60_000)
    }

    @Test @MainActor func bridgeArguments() async throws {
        let (dir, script, argvLog, pathLog) = try Self.installArgLogScript()
        defer {
            MuseCodeMSPBridge.shared.stopHost()
            try? FileManager.default.removeItem(at: dir)
        }
        _ = setenv("MSP_ARGV_LOG", argvLog.path, 1)
        _ = setenv("MSP_PATH_LOG", pathLog.path, 1)
        defer {
            unsetenv("MSP_ARGV_LOG")
            unsetenv("MSP_PATH_LOG")
        }
        let bridge = MuseCodeMSPBridge.shared

        try await bridge.startHost(executable: script.path, workspaceRoot: dir.path,
                                   baseURL: "http://127.0.0.1:19855")
        #expect(bridge.isRunning)
        let argvText = await Self.waitForNonEmptyFile(argvLog)
        #expect(argvText?.components(separatedBy: "\n").filter { !$0.isEmpty } ==
            ["--base-url", "http://127.0.0.1:19855", "serve"])
        bridge.stopHost()

        try await bridge.startHost(executable: script.path, workspaceRoot: dir.path)
        let argvText2 = await Self.waitForNonEmptyFile(argvLog)
        #expect(argvText2?.components(separatedBy: "\n").filter { !$0.isEmpty } == ["serve"])
    }

    @Test @MainActor func bridgeEnvironmentAppendsHomebrewPaths() async throws {
        let (dir, script, argvLog, pathLog) = try Self.installArgLogScript()
        defer {
            MuseCodeMSPBridge.shared.stopHost()
            try? FileManager.default.removeItem(at: dir)
        }
        let oldPath = getenv("PATH").map { String(cString: $0) }
        _ = setenv("PATH", "/usr/bin", 1)
        _ = setenv("MSP_ARGV_LOG", argvLog.path, 1)
        _ = setenv("MSP_PATH_LOG", pathLog.path, 1)
        defer {
            if let oldPath { _ = setenv("PATH", oldPath, 1) }
            unsetenv("MSP_ARGV_LOG")
            unsetenv("MSP_PATH_LOG")
        }

        try await MuseCodeMSPBridge.shared.startHost(executable: script.path, workspaceRoot: dir.path)
        let pathText = await Self.waitForNonEmptyFile(pathLog)
        #expect(pathText == "/usr/bin:/opt/homebrew/bin:/usr/local/bin")
    }

    @Test @MainActor func bridgeStartWithoutExecutableThrows() async {
        do {
            try await MuseCodeMSPBridge.shared.startHost(executable: "/nonexistent/muse", workspaceRoot: "/tmp")
            Issue.record("expected startHost to throw")
        } catch {
            #expect(MuseCodeMSPBridge.shared.isRunning == false)
        }
    }

    @Test func normalizeToolName() {
        let known: Set<String> = ["file_read", "file_write", "plan-AskUser", "use_terminal"]
        #expect(MetaToolNameNormalizer.normalize(nil).name == "system_tool")
        #expect(MetaToolNameNormalizer.normalize("").name == "system_tool")
        #expect(MetaToolNameNormalizer.normalize("Muse.file_read", knownToolIDs: known) ==
            MetaNormalizedToolName(name: "file_read", source: .registry))
        #expect(MetaToolNameNormalizer.normalize("muse_file_write", knownToolIDs: known) ==
            MetaNormalizedToolName(name: "file_write", source: .registry))
        #expect(MetaToolNameNormalizer.normalize("FILE_READ", knownToolIDs: known) ==
            MetaNormalizedToolName(name: "file_read", source: .registry))
        #expect(MetaToolNameNormalizer.normalize("use workers") ==
            MetaNormalizedToolName(name: "use_workers", source: .synonym))
        #expect(MetaToolNameNormalizer.normalize("Muse.plan-askuser") ==
            MetaNormalizedToolName(name: "plan-AskUser", source: .synonym))
        #expect(MetaToolNameNormalizer.normalize("report") ==
            MetaNormalizedToolName(name: "report_to_user", source: .synonym))
        #expect(MetaToolNameNormalizer.normalize("bash") ==
            MetaNormalizedToolName(name: "use_terminal", source: .alias))
        let unmapped = MetaToolNameNormalizer.normalize("some_future_tool")
        #expect(unmapped == MetaNormalizedToolName(name: "some_future_tool", source: .passthrough))
        #expect(MetaToolNameNormalizer.normalize("file_read").source == .passthrough)
    }

    @Test func notificationRouting() {
        var tracker: [String: MetaTurnItemState] = [:]
        var unmapped: [String] = []
        let known: Set<String> = ["read_file"]

        let started = MetaTurnNotificationRouter.route(
            method: "item/started",
            params: ["item": ["itemId": "c-1", "kind": "toolCall", "tool": "muse.read_file",
                              "args": "{\"path\": \"Sources/App.swift\"}"]],
            tracker: &tracker, unmappedToolNames: &unmapped, knownToolIDs: known, activeTurnID: "t-1")
        #expect(started.contains(.toolStarted(callID: "c-1", toolName: "read_file",
                                              argumentsJSON: "{\"path\": \"Sources/App.swift\"}", isMuseTool: true)))
        #expect(started.contains(.activity("read_file: Sources/App.swift")))
        #expect(unmapped.isEmpty)

        let delta = MetaTurnNotificationRouter.route(
            method: "item/delta",
            params: ["itemId": "c-1", "field": "output", "delta": "ok\n"],
            tracker: &tracker, unmappedToolNames: &unmapped, knownToolIDs: known, activeTurnID: "t-1")
        #expect(delta == [.toolProgress(callID: "c-1", message: "ok")])
        #expect(tracker["c-1"]?.output == "ok\n")

        _ = MetaTurnNotificationRouter.route(
            method: "item/started",
            params: ["item": ["itemId": "c-2", "kind": "toolCall", "tool": "muse.future_tool", "args": "{}"]],
            tracker: &tracker, unmappedToolNames: &unmapped, knownToolIDs: known, activeTurnID: "t-1")
        #expect(unmapped == ["future_tool"])
        _ = MetaTurnNotificationRouter.route(
            method: "item/completed",
            params: ["item": ["itemId": "c-2", "kind": "toolCall", "tool": "muse.future_tool",
                              "args": "{}", "visibleOutput": "done"]],
            tracker: &tracker, unmappedToolNames: &unmapped, knownToolIDs: known, activeTurnID: "t-1")
        #expect(unmapped == ["future_tool"])

        var tracker2: [String: MetaTurnItemState] = ["i-1": MetaTurnItemState(kind: "agentMessage", tool: nil, args: "")]
        var unmapped2: [String] = []
        #expect(MetaTurnNotificationRouter.route(
            method: "item/delta",
            params: ["itemId": "i-1", "field": "text", "delta": "hi"],
            tracker: &tracker2, unmappedToolNames: &unmapped2, knownToolIDs: known, activeTurnID: "t-1") == [.text("hi")])
        tracker2["i-1"] = MetaTurnItemState(kind: "reasoning", tool: nil, args: "")
        #expect(MetaTurnNotificationRouter.route(
            method: "item/delta",
            params: ["itemId": "i-1", "field": "summary", "delta": "thinking…"],
            tracker: &tracker2, unmappedToolNames: &unmapped2, knownToolIDs: known, activeTurnID: "t-1") == [.thinking("thinking…")])
        #expect(MetaTurnNotificationRouter.route(
            method: "turn/completed", params: ["turnId": "t-1"],
            tracker: &tracker2, unmappedToolNames: &unmapped2, knownToolIDs: known, activeTurnID: "t-1") ==
            [.turnCompleted(turnID: "t-1")])

        #expect(MetaTurnNotificationRouter.route(
            method: "turn/unqueued", params: ["turnId": "other"],
            tracker: &tracker2, unmappedToolNames: &unmapped2, knownToolIDs: known, activeTurnID: "t-1") == [.ignored])
        #expect(MetaTurnNotificationRouter.route(
            method: "turn/unqueued", params: ["turnId": "t-1"],
            tracker: &tracker2, unmappedToolNames: &unmapped2, knownToolIDs: known, activeTurnID: "t-1") ==
            [.turnUnqueued(turnID: "t-1")])

        #expect(MetaTurnNotificationRouter.route(
            method: "session/modelChanged", params: ["modelId": "muse-spark-1.3"],
            tracker: &tracker2, unmappedToolNames: &unmapped2, knownToolIDs: known, activeTurnID: "t-1") ==
            [.modelChanged("muse-spark-1.3")])
        let approval = MetaTurnNotificationRouter.route(
            method: "approval/requested",
            params: ["sessionId": "s-1", "approvalId": "a-1", "action": "run tests"],
            tracker: &tracker2, unmappedToolNames: &unmapped2, knownToolIDs: known, activeTurnID: "t-1")
        #expect(approval == [.approvalRequested(sessionID: "s-1", approvalID: "a-1", action: "run tests", requirement: nil)])
        #expect(MetaTurnNotificationRouter.route(
            method: "approval/resolved", params: ["decision": "allow"],
            tracker: &tracker2, unmappedToolNames: &unmapped2, knownToolIDs: known, activeTurnID: "t-1") == [.ignored])
        #expect(MetaTurnNotificationRouter.route(
            method: "something/new", params: [:],
            tracker: &tracker2, unmappedToolNames: &unmapped2, knownToolIDs: known, activeTurnID: "t-1") == [.ignored])
    }

    @Test @MainActor func parseModelList() {
        let response: AnyJSON = [
            "result": ["models": [
                ["modelId": "muse-wonder-1.0", "displayLabel": "wonder", "contextLimit": 1007997],
                ["displayLabel": "no id"],
                ["modelId": "muse-spark-1.3"],
            ]],
        ]
        let models = MetaAssistTurnExecutor.parseModelList(response)
        #expect(models?.map(\.modelId) == ["muse-wonder-1.0", "muse-spark-1.3"])
        #expect(models?.first?.contextLimit == 1007997)
        #expect(models?.last?.contextLimit == 1_000_000)
        #expect(MetaAssistTurnExecutor.parseModelList(["result": ["models": []]]) == nil)
        #expect(MetaAssistTurnExecutor.parseModelList([:]) == nil)
    }

    @Test @MainActor func parseSessionID() {
        #expect(MetaAssistTurnExecutor.parseSessionID(
            ["result": ["session": ["sessionId": "a"]]], fallback: "f") == "a")
        #expect(MetaAssistTurnExecutor.parseSessionID(
            ["session": ["sessionId": "b"]], fallback: "f") == "b")
        #expect(MetaAssistTurnExecutor.parseSessionID(
            ["sessionId": "c"], fallback: "f") == "c")
        #expect(MetaAssistTurnExecutor.parseSessionID([:], fallback: "f") == "f")
    }

    @Test @MainActor func rateLimitClassification() {
        #expect(MetaAssistTurnExecutor.isRateLimitError(
            MuseCodeMSPError(code: -32000, message: "limit", kind: nil, data: ["reason": "rate_limit_exceeded"])))
        #expect(MetaAssistTurnExecutor.isRateLimitError(
            MuseCodeMSPError(code: 429, message: "Too Many Requests", kind: "quota", data: nil)))
        #expect(MetaAssistTurnExecutor.isRateLimitError(AssistantError.failed("HTTP 429: quota exceeded")))
        #expect(MetaAssistTurnExecutor.isRateLimitError(AssistantError.failed("the model is overloaded right now")))
        #expect(!MetaAssistTurnExecutor.isRateLimitError(AssistantError.failed("the host went away")))
        #expect(!MetaAssistTurnExecutor.isRateLimitError(MuseCodeCLIError.executableNotFound))
        #expect(MetaAssistTurnExecutor.isSessionNotLoaded(
            MuseCodeMSPError(code: -32000, message: "x", kind: "sessionNotLoaded", data: nil)))
        #expect(MetaAssistTurnExecutor.isSessionNotLoaded(
            AssistantError.failed("session abc is not loaded on this host")))
        #expect(!MetaAssistTurnExecutor.isSessionNotLoaded(AssistantError.failed("boom")))
    }

    @Test @MainActor func effectivePrompt() {
        let history = (1...13).map { ChatMessage(.user, "turn \($0)") }
        let prompt = MetaAssistTurnExecutor.buildEffectivePrompt(
            instructions: "Be helpful.", history: history, prompt: "turn 13")
        #expect(prompt.hasPrefix("Be helpful."))
        #expect(prompt.contains("# CURRENT USER REQUEST\nturn 13"))
        #expect(prompt.components(separatedBy: "[User]:").count - 1 == 12)
        #expect(prompt.components(separatedBy: "turn 13").count - 1 == 1)
    }

    @Test func slashCatalog() {
        #expect(MetaSlashCommandManager.builtInCommands.count == 36)
        let ids = MetaSlashCommandManager.builtInCommands.map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(MetaSlashCommandManager.builtInCommands.allSatisfy { $0.name.hasPrefix("/") })
        let manager = MetaSlashCommandManager()
        #expect(manager.searchCommands(query: "").count == 36)
        #expect(manager.searchCommands(query: "/effort").map(\.id) == ["effort"])
        #expect(manager.searchCommands(query: "model").contains { $0.id == "model" })
        #expect(manager.searchCommands(query: "no-such-command").isEmpty)
    }

    @Test func slashExecuteEffects() {
        let manager = MetaSlashCommandManager()
        let effort = manager.commands.first { $0.id == "effort" }!
        #expect(manager.executeCommand(effort, argument: "low") ==
            (text: "Meta reasoning effort set to 'low'.", effect: .setReasoningEffort("low")))
        // A missing argument falls back to inserting the bare command name.
        #expect(manager.executeCommand(effort, argument: nil) ==
            (text: "/effort", effect: .insertText("/effort")))
        let model = manager.commands.first { $0.id == "model" }!
        #expect(manager.executeCommand(model, argument: "muse-spark-1.3") ==
            (text: "Meta Assist model switched to 'muse-spark-1.3'.", effect: .setModel("muse-spark-1.3")))
        let clear = manager.commands.first { $0.id == "clear" }!
        #expect(manager.executeCommand(clear, argument: nil) ==
            (text: "Cleared Assist session.", effect: .clearSession))
        let login = manager.commands.first { $0.id == "login" }!
        #expect(manager.executeCommand(login, argument: nil) ==
            (text: "Starting Meta authentication flow...", effect: .startLogin))
        let help = manager.commands.first { $0.id == "help" }!
        #expect(manager.executeCommand(help, argument: nil) == (text: "/help", effect: .insertText("/help")))
        #expect(manager.executeCommand(help, argument: "topics") ==
            (text: "/help topics", effect: .insertText("/help topics")))
    }

    @Test func slashSkillsListParsing() {
        let output = """
            # comment line
            replica-architect\t skill\t x\t y\t Designs replica architectures
            my_skill\t skill\t x\t Short desc
            bare
            \t skill\t x\t y\t Nameless
            """
        let skills = MetaSlashCommandManager.parseSkillsList(output)
        #expect(skills.map(\.id) == ["skill-replica-architect", "skill-my_skill"])
        #expect(skills[0].title == "Replica Architect")
        #expect(skills[0].description == "Designs replica architectures")
        #expect(skills[1].description == "Short desc")
        #expect(skills[0].isTerminalSkill && skills[0].category == "Meta Skills")

        var manager = MetaSlashCommandManager()
        let merged = manager.mergeCapturedSkills(skills)
        #expect(merged)
        #expect(manager.commands.count == 36 + 2)
        #expect(manager.lastCapturedAt != nil)
        let noneMerged = manager.mergeCapturedSkills([])
        #expect(!noneMerged)
        let again = MetaSlashCommandManager.parseSkillsList("only-one\t skill\t x\t y\t One\n")
        let againMerged = manager.mergeCapturedSkills(again)
        #expect(againMerged)
        #expect(manager.commands.count == 36 + 1)
        #expect(manager.commands.last?.id == "skill-only-one")
    }

    @Test func slashCaptureFromTerminal() async {
        var manager = MetaSlashCommandManager()
        await manager.captureCommandsFromTerminal(executable: nil)
        #expect(manager.commands.count == 36)
        await manager.captureCommandsFromTerminal(executable: URL(fileURLWithPath: "/bin/true")) { _ in
            "fresh-skill\t skill\t x\t y\t Fresh\n"
        }
        #expect(manager.commands.count == 37)
        #expect(manager.commands.last?.id == "skill-fresh-skill")
        await manager.captureCommandsFromTerminal(executable: URL(fileURLWithPath: "/bin/true")) { _ in
            throw MuseCodeCLIError.timeout
        }
        #expect(manager.commands.count == 37)
    }

    @Test @MainActor func otherModelsAvailableModels() {
        let all = MuseOtherModelsBridge.shared.availableOtherModels(onlyUseFree: false)
        #expect(!all.isEmpty)
        let free = MuseOtherModelsBridge.shared.availableOtherModels(onlyUseFree: true)
        #expect(!free.isEmpty)
        #expect(free.allSatisfy {
            AssistModelEligibilityPolicy.isEligible(modelID: $0.modelIdentifier, onlyUseFreeModels: true)
        })
    }

    @Test func otherModelsProxyCatalog() async throws {
        let active = MuseOtherModelResolution(modelID: "gpt-4o", displayName: "OpenAI GPT-4o", provider: "OpenAI")
        let proxy = MuseLocalProxyServer()
        let url = try proxy.start(active: active, port: 0)
        defer { proxy.stop() }
        #expect(proxy.isRunning)
        #expect(proxy.activeModel == active)

        let catalogRequest = URLRequest(url: url.appendingPathComponent("/v1/models"))
        let catalog = try await HTTP.send(catalogRequest, timeout: 10)
        #expect(catalog.status == 200)
        let catalogJSON = try JSONSerialization.jsonObject(with: catalog.body) as? [String: Any]
        let data = catalogJSON?["data"] as? [[String: Any]]
        #expect(!(data?.first?["id"] as? String ?? "").isEmpty)
        let meta = (data?.first?["metadata"] as? [String: Any])?["muse-code"] as? [String: Any]
        #expect(meta?["family"] as? String == "custom-bridge")
        #expect((meta?["limit"] as? [String: Any])?["context"] as? Int == 128_000)

        let missing = try await HTTP.send(URLRequest(url: url.appendingPathComponent("/nope")), timeout: 10)
        #expect(missing.status == 404)
    }

    @Test @MainActor func lifecycleMonitoringAndRestart() async throws {
        let dir = try Self.tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let sleeper = dir.appendingPathComponent("muse")
        try "#!/bin/sh\nsleep 30\n".write(to: sleeper, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: sleeper.path)

        let bridge = MuseCodeMSPBridge.shared
        let manager = MetaAssistLifecycleManager(
            workspaceRoot: { dir.path },
            executable: { sleeper },
            isMetaActive: { true })
        await manager.startMonitoring()
        #expect(await manager.isMonitoring)
        await manager.stopEngine()
        #expect(await manager.stoppedIntentionally)
        #expect(await manager.healthCheckOnce() == false)
        #expect(await manager.restartCount == 0)
        try await manager.startEngine(workspaceRoot: dir.path, executable: sleeper)
        #expect(await manager.stoppedIntentionally == false)
        #expect(bridge.isRunning)
        bridge.stopHost()
        #expect(bridge.isRunning == false)
        #expect(await manager.healthCheckOnce() == true)
        #expect(await manager.restartCount == 1)
        #expect(bridge.isRunning)
        #expect(await manager.healthCheckOnce() == false)
        await manager.stopMonitoring()
        #expect(await manager.isMonitoring == false)
        bridge.stopHost()
    }

    @Test @MainActor func lifecycleWithoutExecutableIsIdle() async throws {
        let manager = MetaAssistLifecycleManager(isMetaActive: { true })
        try await manager.startEngine(workspaceRoot: "/tmp", executable: nil)
        #expect(MuseCodeMSPBridge.shared.isRunning == false)
        #expect(await manager.healthCheckOnce() == false)
    }

    @Test @MainActor func executorListsLiveModelsAndRunsTurn() async throws {
        guard Self.pythonAvailable() else { return }
        let (dir, _, script) = try Self.installFakeMuse()
        defer {
            Self.clearFakeMuseEnv()
            try? FileManager.default.removeItem(at: dir)
        }
        let bridge = MuseCodeMSPBridge.shared
        defer { bridge.stopHost() }

        let models = try await MetaAssistProvider.shared.fetchModels()
        #expect(models.map(\.id) == ["muse-wonder-1.0"])

        let executor = MetaAssistTurnExecutor()
        let events = ChatEventLog()
        try await executor.executeTurn(
            prompt: "Say hello",
            instructions: "Be helpful.",
            modelID: "muse-wonder-1.0",
            workspaceRoot: dir.path,
            executable: script,
            hasCredentials: true,
            onEvent: { events.add($0) })
        #expect(events.text == "Hello world")
        #expect(executor.activeSessionID == "sess-1")
        #expect(executor.lastTurnUnmappedToolNames.isEmpty)

        let events2 = ChatEventLog()
        try await executor.executeTurn(
            prompt: "Say hello",
            instructions: "Be helpful.",
            modelID: "muse-wonder-1.0",
            workspaceRoot: dir.path,
            executable: script,
            hasCredentials: true,
            onEvent: { events2.add($0) })
        #expect(events2.text == "Hello world")
    }

    @Test @MainActor func executorDeniesApprovalWithoutAttachment() async throws {
        guard Self.pythonAvailable() else { return }
        let (dir, log, script) = try Self.installFakeMuse(approval: true)
        defer {
            Self.clearFakeMuseEnv()
            try? FileManager.default.removeItem(at: dir)
        }
        let bridge = MuseCodeMSPBridge.shared
        defer { bridge.stopHost() }

        let executor = MetaAssistTurnExecutor()
        let events = ChatEventLog()
        try await executor.executeTurn(
            prompt: "Run tests",
            instructions: "",
            modelID: "muse-wonder-1.0",
            workspaceRoot: dir.path,
            executable: script,
            hasCredentials: true,
            onEvent: { events.add($0) })
        #expect(events.text == "Hello world")
        // approval/decide is sent asynchronously after turn/completed may
        // already have resumed the turn, so poll the method log briefly.
        var logged = ""
        for _ in 0..<40 {
            logged = (try? String(contentsOf: log, encoding: .utf8)) ?? ""
            if logged.contains("approval/decide") { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        #expect(logged.contains("approval/decide"))
    }

    @Test @MainActor func executorApprovalAsksAttachment() async throws {
        guard Self.pythonAvailable() else { return }
        let (dir, log, script) = try Self.installFakeMuse(approval: true)
        defer {
            Self.clearFakeMuseEnv()
            try? FileManager.default.removeItem(at: dir)
        }
        let bridge = MuseCodeMSPBridge.shared
        defer { bridge.stopHost() }

        let asked = PermissionAskedBox()
        let attachment = AgentAttachment(
            requestPermission: { title, options in
                asked.add(title, options)
                return "allow_once"
            })
        let executor = MetaAssistTurnExecutor()
        let events = ChatEventLog()
        try await executor.executeTurn(
            prompt: "Run tests",
            instructions: "",
            modelID: "muse-wonder-1.0",
            workspaceRoot: dir.path,
            executable: script,
            hasCredentials: true,
            attachment: attachment,
            onEvent: { events.add($0) })
        #expect(events.text == "Hello world")
        var logged = ""
        for _ in 0..<40 {
            logged = (try? String(contentsOf: log, encoding: .utf8)) ?? ""
            if logged.contains("approval/decide") && !asked.all.isEmpty { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        #expect(asked.all.count == 1)
        #expect(asked.all[0].0.contains("run tests"))
        #expect(asked.all[0].1.map(\.id) == ["allow_once", "abort"])
        #expect(logged.contains("approval/decide"))
    }

    @Test @MainActor func executorSendFailsHonestlyWithoutBinary() async {
        let executor = MetaAssistTurnExecutor()
        do {
            try await executor.executeTurn(
                prompt: "Hello",
                instructions: "Be helpful.",
                modelID: "muse-wonder-1.0",
                workspaceRoot: "/tmp",
                executable: nil,
                hasCredentials: true,
                onEvent: { _ in })
            Issue.record("expected executeTurn to throw")
        } catch let error as MuseCodeCLIError {
            guard case .executableNotFound = error else {
                Issue.record("expected executableNotFound, got \(error)")
                return
            }
        } catch {
            Issue.record("expected MuseCodeCLIError, got \(error)")
        }
    }

    @Test @MainActor func executorSendFailsHonestlyWithoutCredentials() async {
        let executor = MetaAssistTurnExecutor()
        do {
            try await executor.executeTurn(
                prompt: "Hello",
                instructions: "",
                modelID: "muse-wonder-1.0",
                workspaceRoot: "/tmp",
                executable: URL(fileURLWithPath: "/bin/true"),
                hasCredentials: false,
                onEvent: { _ in })
            Issue.record("expected executeTurn to throw")
        } catch let error as AssistantError {
            guard case .notSignedIn = error else {
                Issue.record("expected notSignedIn, got \(error)")
                return
            }
        } catch {
            Issue.record("expected AssistantError, got \(error)")
        }
    }
}
