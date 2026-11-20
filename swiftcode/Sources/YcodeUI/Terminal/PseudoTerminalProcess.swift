import Darwin
import Foundation

public struct PseudoTerminalError: Error, CustomStringConvertible {
    public let description: String
    public init(_ description: String) { self.description = description }
}

public final class PseudoTerminalProcess: @unchecked Sendable {
    public private(set) var pid: pid_t = 0
    public private(set) var isRunning = false
    public var onOutput: (@MainActor (Data) -> Void)?
    public var onExit: (@MainActor (Int32) -> Void)?

    private var master: Int32 = -1
    private var readSource: DispatchSourceRead?
    private var exitSource: DispatchSourceProcess?
    private let ioQueue = DispatchQueue(label: "dev.swiftcode.terminal.pty")
    private let lock = NSLock()
    private var pending = Data()
    private var flushScheduled = false
    private var readerFinished = false
    private var exitStatus: Int32?

    public init() {}

    deinit {
        readSource?.cancel()
        exitSource?.cancel()
        if isRunning { kill(pid, SIGHUP) }
    }

    public static func defaultShell() -> String {
        if let s = ProcessInfo.processInfo.environment["SHELL"], FileManager.default.isExecutableFile(atPath: s) { return s }
        if let pw = getpwuid(getuid()), let sh = pw.pointee.pw_shell {
            let s = String(cString: sh)
            if FileManager.default.isExecutableFile(atPath: s) { return s }
        }
        return "/bin/zsh"
    }

    public static func availableShells() -> [String] {
        let listed = (try? String(contentsOfFile: "/etc/shells", encoding: .utf8))?
            .split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("/") } ?? []
        var seen = Set<String>()
        return ([defaultShell()] + listed).filter { FileManager.default.isExecutableFile(atPath: $0) && seen.insert($0).inserted }
    }

    public static func environment(overrides: [String: String] = [:]) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["COLORTERM"] = "truecolor"
        env["TERM_PROGRAM"] = "SwiftCode"
        if env["LANG"] == nil && env["LC_ALL"] == nil { env["LANG"] = "en_US.UTF-8" }
        for key in ["TERM_SESSION_ID", "TERM_PROGRAM_VERSION", "OS_ACTIVITY_DT_MODE", "__XCODE_BUILT_PRODUCTS_DIR_PATHS", "__XPC_DYLD_LIBRARY_PATH",
                    "__XPC_DYLD_FRAMEWORK_PATH", "DYLD_LIBRARY_PATH", "DYLD_FRAMEWORK_PATH"] { env[key] = nil }
        for (k, v) in overrides { env[k] = v }
        return env
    }

    public func start(executable: String, arguments: [String] = [], loginShell: Bool = true, environment: [String: String],
                      workingDirectory: String, columns: Int, rows: Int) throws {
        guard !isRunning else { throw PseudoTerminalError("The process is already running") }
        var m: Int32 = -1, s: Int32 = -1
        var size = winsize(ws_row: UInt16(clamping: rows), ws_col: UInt16(clamping: columns), ws_xpixel: 0, ws_ypixel: 0)
        guard openpty(&m, &s, nil, nil, &size) == 0 else { throw PseudoTerminalError("openpty failed: \(String(cString: strerror(errno)))") }
        defer { close(s) }
        guard let name = ttyname(s) else { close(m); throw PseudoTerminalError("ttyname failed") }
        let slavePath = String(cString: name)
        _ = fcntl(m, F_SETFD, FD_CLOEXEC)

        var actions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&actions)
        defer { posix_spawn_file_actions_destroy(&actions) }
        posix_spawn_file_actions_addopen(&actions, 0, slavePath, O_RDWR, 0)
        posix_spawn_file_actions_adddup2(&actions, 0, 1)
        posix_spawn_file_actions_adddup2(&actions, 0, 2)
        var isDir: ObjCBool = false
        let cwd = FileManager.default.fileExists(atPath: workingDirectory, isDirectory: &isDir) && isDir.boolValue ? workingDirectory : NSHomeDirectory()
        if #available(macOS 26.0, *) {
            posix_spawn_file_actions_addchdir(&actions, cwd)
        } else {
            posix_spawn_file_actions_addchdir_np(&actions, cwd)
        }

        var attr: posix_spawnattr_t?
        posix_spawnattr_init(&attr)
        defer { posix_spawnattr_destroy(&attr) }
        var defaults = sigset_t(), mask = sigset_t()
        sigfillset(&defaults)
        sigemptyset(&mask)
        posix_spawnattr_setsigdefault(&attr, &defaults)
        posix_spawnattr_setsigmask(&attr, &mask)
        posix_spawnattr_setflags(&attr, Int16(POSIX_SPAWN_SETSID | POSIX_SPAWN_CLOEXEC_DEFAULT | POSIX_SPAWN_SETSIGDEF | POSIX_SPAWN_SETSIGMASK))

        let base = (executable as NSString).lastPathComponent
        let argv0 = loginShell ? "-" + base : base
        var env = environment
        env["PWD"] = cwd
        let argv: [UnsafeMutablePointer<CChar>?] = ([argv0] + arguments).map { strdup($0) } + [nil]
        let envp: [UnsafeMutablePointer<CChar>?] = env.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer {
            argv.forEach { free($0) }
            envp.forEach { free($0) }
        }
        var child: pid_t = 0
        let rc = posix_spawn(&child, executable, &actions, &attr, argv, envp)
        guard rc == 0 else {
            close(m)
            throw PseudoTerminalError("Could not start \(executable): \(String(cString: strerror(rc)))")
        }
        master = m
        pid = child
        isRunning = true
        readerFinished = false
        exitStatus = nil

        let source = DispatchSource.makeReadSource(fileDescriptor: m, queue: ioQueue)
        source.setEventHandler { [weak self] in self?.readAvailable() }
        source.setCancelHandler { close(m) }
        readSource = source
        source.resume()

        let exit = DispatchSource.makeProcessSource(identifier: child, eventMask: .exit, queue: ioQueue)
        exit.setEventHandler { [weak self] in
            var status: Int32 = 0
            waitpid(child, &status, 0)
            let code = (status & 0x7f) == 0 ? (status >> 8) & 0xff : 128 + (status & 0x7f)
            self?.childExited(code)
        }
        exitSource = exit
        exit.resume()
    }

    private func readAvailable() {
        var buffer = [UInt8](repeating: 0, count: 65536)
        let n = read(master, &buffer, buffer.count)
        if n > 0 {
            lock.lock()
            pending.append(buffer, count: n)
            let schedule = !flushScheduled
            flushScheduled = true
            lock.unlock()
            if schedule { DispatchQueue.main.async { [weak self] in self?.flush() } }
        } else if n == 0 || (errno != EAGAIN && errno != EINTR) {
            readSource?.cancel()
            readSource = nil
            readerFinished = true
            finishIfDone()
        }
    }

    private func flush() {
        lock.lock()
        let data = pending
        pending = Data()
        flushScheduled = false
        lock.unlock()
        guard !data.isEmpty else { return }
        MainActor.assumeIsolated { onOutput?(data) }
    }

    private func childExited(_ code: Int32) {
        exitSource?.cancel()
        exitSource = nil
        exitStatus = code
        if !readerFinished {
            ioQueue.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                guard let self, !self.readerFinished else { return }
                self.readSource?.cancel()
                self.readSource = nil
                self.readerFinished = true
                self.finishIfDone()
            }
        }
        finishIfDone()
    }

    private func finishIfDone() {
        guard readerFinished, let code = exitStatus, isRunning else { return }
        isRunning = false
        master = -1
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.flush()
            MainActor.assumeIsolated { self.onExit?(code) }
        }
    }

    public func write(_ data: Data) {
        guard isRunning, !data.isEmpty else { return }
        let fd = master
        ioQueue.async {
            data.withUnsafeBytes { raw in
                guard var p = raw.baseAddress else { return }
                var left = raw.count
                var stalls = 0
                while left > 0 {
                    let n = Darwin.write(fd, p, left)
                    if n > 0 {
                        p += n
                        left -= n
                        stalls = 0
                    } else if errno == EINTR {
                        continue
                    } else if errno == EAGAIN, stalls < 200 {
                        stalls += 1
                        usleep(5000)
                    } else {
                        return
                    }
                }
            }
        }
    }

    public func write(_ string: String) { write(Data(string.utf8)) }

    public func resize(columns: Int, rows: Int) {
        guard isRunning else { return }
        var size = winsize(ws_row: UInt16(clamping: rows), ws_col: UInt16(clamping: columns), ws_xpixel: 0, ws_ypixel: 0)
        _ = ioctl(master, TIOCSWINSZ, &size)
    }

    public func send(signal: Int32) {
        guard isRunning else { return }
        let group = tcgetpgrp(master)
        if group > 0 { killpg(group, signal) } else { kill(pid, signal) }
    }

    public func terminate() {
        guard isRunning else { return }
        kill(pid, SIGHUP)
        let child = pid
        ioQueue.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            if self?.isRunning == true, self?.pid == child { kill(child, SIGKILL) }
        }
    }

    public var foregroundProcessName: String? {
        guard isRunning else { return nil }
        let group = tcgetpgrp(master)
        guard group > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: 256)
        guard proc_name(group, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return String(cString: buffer)
    }

    public var hasForegroundJob: Bool {
        guard isRunning else { return false }
        let group = tcgetpgrp(master)
        return group > 0 && group != pid
    }

    public var currentDirectory: String? {
        guard isRunning else { return nil }
        var info = proc_vnodepathinfo()
        let size = Int32(MemoryLayout<proc_vnodepathinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, size) == size else { return nil }
        return withUnsafePointer(to: &info.pvi_cdir.vip_path) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
        }
    }
}
