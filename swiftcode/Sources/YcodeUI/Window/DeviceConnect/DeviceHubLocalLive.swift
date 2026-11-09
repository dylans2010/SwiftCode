#if os(macOS)
import AppKit
import Foundation
import YcodeDeviceModel
import YcodeDeviceUI
import YcodeDisplayStream
import YcodeIDECore










final class LocalSimTransport: DisplayTransport, @unchecked Sendable {
    
    
    var onClientMessage: (@Sendable (DisplayMessage) -> Void)?

    private let cond = NSCondition()
    private var pending: [UInt8] = []
    private var closed = false
    private var parser = DisplayMessageParser()

    
    func enqueue(_ message: DisplayMessage) {
        cond.lock()
        pending += message.encoded()
        cond.signal()
        cond.unlock()
    }

    func send(_ bytes: [UInt8]) throws {
        parser.append(bytes)
        while let m = try parser.next() {
            onClientMessage?(m)
        }
    }

    func receive(max: Int) -> [UInt8]? {
        cond.lock()
        while pending.isEmpty && !closed { cond.wait() }
        guard !pending.isEmpty else { cond.unlock(); return nil }
        let n = min(max, pending.count)
        let out = Array(pending.prefix(n))
        pending.removeFirst(n)
        cond.unlock()
        return out
    }

    func close() {
        cond.lock()
        closed = true
        cond.signal()
        cond.unlock()
    }
}







final class LocalSimPump: @unchecked Sendable {
    let udid: String
    let deviceName: String
    let model: String
    let osVersion: String
    let deviceTypeID: String?
    let spec: DeviceFrameSpec
    let interval: TimeInterval

    private let transport: LocalSimTransport
    private var thread: Thread?
    private var stopped = false
    private var captureNow = false
    private let lock = NSLock()
    private var helloSent = false
    private var frameSequence: UInt64 = 0
    private var guestFrame: UInt64 = 0
    private var pngData: [UInt8] = []
    private var lastImageSize: CGSize = .zero

    init(udid: String, name: String, model: String, osVersion: String, deviceTypeID: String?, spec: DeviceFrameSpec,
         transport: LocalSimTransport, interval: TimeInterval = 0.6) {
        self.udid = udid
        self.deviceName = name
        self.model = model
        self.osVersion = osVersion
        self.deviceTypeID = deviceTypeID
        self.spec = spec
        self.transport = transport
        self.interval = interval
    }

    func start() {
        let t = Thread { [self] in run() }
        t.name = "device-hub-local-sim-\(udid)"
        thread = t
        t.start()
    }

    func stop() {
        lock.withLock { stopped = true }
        transport.close()
    }

    
    func requestFrame() { lock.withLock { captureNow = true } }

    
    var latestPNG: [UInt8] { lock.withLock { pngData } }

    private func run() {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("swiftcode-hub-shot-\(udid)-\(getpid()).png")
        defer { try? FileManager.default.removeItem(at: tmp) }
        while !lock.withLock({ stopped }) {
            if let shot = capture(to: tmp) {
                publish(shot)
            }
            
            let deadline = Date().addingTimeInterval(interval)
            while Date() < deadline, !lock.withLock({ stopped || captureNow }) {
                Thread.sleep(forTimeInterval: 0.05)
            }
            _ = lock.withLock { captureNow = false }
        }
    }

    
    private func capture(to url: URL) -> (png: [UInt8], image: CGImage, width: Int, height: Int)? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "io", udid, "screenshot", url.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        guard process.terminationStatus == 0, let png = try? Data(contentsOf: url), !png.isEmpty,
              let source = CGImageSourceCreateWithData(png as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        return (Array(png), image, image.width, image.height)
    }

    private func publish(_ shot: (png: [UInt8], image: CGImage, width: Int, height: Int)) {
        lock.withLock {
            pngData = shot.png
            lastImageSize = CGSize(width: shot.width, height: shot.height)
        }
        if !helloSent { sendHello() }
        guestFrame += 1
        frameSequence += 1
        let jpeg = Self.jpegData(image: shot.image, quality: 0.65)
        guard !jpeg.isEmpty else { return }
        let frame = DisplayFrame(sequence: frameSequence, guestFrame: guestFrame,
                                 serverNanoseconds: nowNanoseconds(), inputSequence: 0,
                                 width: shot.width, height: shot.height, encoding: .jpeg,
                                 isFull: true, tiles: [DisplayTile(x: 0, y: 0, width: shot.width, height: shot.height, data: jpeg)])
        transport.enqueue(.frame(frame))
    }

    private func sendHello() {
        helloSent = true
        let panel = spec.panels[0]
        var h = DisplayServerHello(deviceName: deviceName, model: model,
                                   pixelWidth: panel.pixelWidth, pixelHeight: panel.pixelHeight,
                                   scale: panel.scale,
                                   orientation: lastImageSize.width > lastImageSize.height ? "landscape" : "portrait",
                                   encodings: ["jpeg"], touch: false, keyboard: false,
                                   buttons: [], rotation: false)
        h.deviceType = deviceTypeID
        h.osVersion = osVersion
        transport.enqueue(.hello(h))
        transport.enqueue(.status(DisplayStatus(phase: "live", uptimeMilliseconds: 0, guestFrames: 0)))
    }

    static func jpegData(image: CGImage, quality: CGFloat) -> [UInt8] {
        let rep = NSBitmapImageRep(cgImage: image)
        return rep.representation(using: .jpeg, properties: [.compressionFactor: quality]).map { [UInt8]($0) } ?? []
    }
}




@MainActor
final class LocalSimLink {
    let session: DeviceLiveSession
    let udid: String
    private let transport = LocalSimTransport()
    private var pump: LocalSimPump?

    init(row: DeviceRow, spec: DeviceFrameSpec, liveFPS: Double = 1.4) {
        udid = row.identifier
        let hello = DisplayClientHello(client: "SwiftCode Device Hub", maxFPS: 15, encoding: "jpeg", quality: 70, downscale: 1)
        let vc = ViewerConnection(address: .unix("local-sim://\(row.identifier)"), settings: hello) { [transport] in transport }
        session = DeviceLiveSession(connection: vc, spec: spec)
        session.displayName = row.name
        session.osTitle = "\(row.platform) \(row.osVersion)"
        let pump = LocalSimPump(udid: row.identifier, name: row.name, model: row.model,
                                osVersion: row.osVersion, deviceTypeID: row.deviceTypeID,
                                spec: spec, transport: transport, interval: 1.0 / liveFPS)
        self.pump = pump
        transport.onClientMessage = { [weak pump, weak vc] message in
            switch message {
            case .ping(let token):
                vc?.send(.pong(token: token, serverNanoseconds: nowNanoseconds()))
            case .screenshotRequest(let token):
                if let png = pump?.latestPNG, !png.isEmpty {
                    vc?.send(.screenshot(token: token, png: png))
                } else {
                    vc?.send(.screenshot(token: token, png: []))
                }
            case .keyframeRequest:
                pump?.requestFrame()
            case .command(let token, _):
                vc?.send(.commandReply(token: token, text: "error: local simulators do not accept hub commands"))
            default:
                break
            }
        }
        session.start()
        pump.start()
    }

    func close() {
        pump?.stop()
        pump = nil
        session.close()
    }
}



enum DeviceHubSimctl {
    
    @discardableResult
    static func run(_ arguments: [String], timeout: TimeInterval = 30) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = arguments
        let out = Pipe()
        process.standardOutput = out
        process.standardError = out
        process.standardInput = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return (-1, "could not launch xcrun") }
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async {
            process.waitUntilExit()
            group.leave()
        }
        if group.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            return (-2, "timed out")
        }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }

    
    
    static func startRecording(udid: String, deviceName: String, into directory: URL) throws -> (process: Process, url: URL) {
        let stamp = ISO8601DateFormatter.string(from: Date(), timeZone: .current,
                                                formatOptions: [.withYear, .withMonth, .withDay, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime])
            .replacingOccurrences(of: ":", with: "-")
        let url = directory.appendingPathComponent("\(deviceName) Recording \(stamp).mov")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "io", udid, "recordVideo", "--codec=h264", url.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        try process.run()
        return (process, url)
    }

    
    static func stopRecording(_ process: Process) {
        if process.isRunning {
            #if canImport(Darwin)
            Darwin.kill(process.processIdentifier, SIGINT)
            #else
            process.terminate()
            #endif
            
            let deadline = Date().addingTimeInterval(10)
            while process.isRunning, Date() < deadline { Thread.sleep(forTimeInterval: 0.05) }
            if process.isRunning { process.terminate() }
        }
    }

    
    static func overrideStatusBar(udid: String, time: String?, batteryLevel: Int?, batteryState: String?,
                                  wifiBars: Int?, operatorName: String?) -> (status: Int32, output: String) {
        var args = ["simctl", "status_bar", udid, "override"]
        if let time, !time.isEmpty { args += ["--time", time] }
        if let batteryLevel { args += ["--batteryLevel", String(batteryLevel), "--batteryState", batteryState ?? "charged"] }
        if let wifiBars { args += ["--wifiBars", String(wifiBars), "--wifiMode", "active"] }
        if let operatorName, !operatorName.isEmpty { args += ["--operatorName", operatorName] }
        return run(args)
    }

    static func clearStatusBar(udid: String) -> (status: Int32, output: String) {
        run(["simctl", "status_bar", udid, "clear"])
    }

    
    
    static func collectLogs(udid: String, minutes: Int, into directory: URL) -> (status: Int32, output: String, archive: URL?) {
        let archive = directory.appendingPathComponent("sim-\(udid)-logs-\(Int(Date().timeIntervalSince1970)).logarchive")
        let r = run(["simctl", "spawn", udid, "log", "collect", "--last", "\(minutes)m", "--output", archive.path], timeout: 300)
        return (r.status, r.output, FileManager.default.fileExists(atPath: archive.path) ? archive : nil)
    }

    
    static func streamLogs(udid: String) -> (process: Process, output: Pipe)? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "spawn", udid, "log", "stream", "--style", "compact"]
        let out = Pipe()
        process.standardOutput = out
        process.standardError = out
        process.standardInput = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        return (process, out)
    }

    
    
    static func appContainer(udid: String, bundleID: String) -> String? {
        let r = run(["simctl", "get_app_container", udid, bundleID, "app"], timeout: 15)
        let path = r.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return r.status == 0 && path.hasPrefix("/") ? path : nil
    }

    
    
    
    
    
    static func devicePlistURL(udid: String) -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer/CoreSimulator/Devices/\(udid)/device.plist")
    }

    
    
    
    static func renameDevice(udid: String, to name: String) -> (status: Int32, output: String) {
        let url = devicePlistURL(udid: udid)
        guard var plist = NSDictionary(contentsOf: url) as? [String: Any] else {
            return (-1, "could not read \(url.path)")
        }
        plist["name"] = name
        guard let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0),
              (try? data.write(to: url)) != nil else {
            return (-1, "could not write \(url.path)")
        }
        return (0, "")
    }
}
#endif
