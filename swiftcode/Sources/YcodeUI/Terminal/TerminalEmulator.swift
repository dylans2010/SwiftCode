import Foundation

public enum TerminalColor: Equatable, Sendable {
    case standard
    case indexed(UInt8)
    case rgb(UInt8, UInt8, UInt8)
}

public struct TerminalStyle: Equatable, Sendable {
    public struct Flags: OptionSet, Sendable {
        public let rawValue: UInt8
        public init(rawValue: UInt8) { self.rawValue = rawValue }
        public static let bold = Flags(rawValue: 1 << 0)
        public static let dim = Flags(rawValue: 1 << 1)
        public static let italic = Flags(rawValue: 1 << 2)
        public static let underline = Flags(rawValue: 1 << 3)
        public static let inverse = Flags(rawValue: 1 << 4)
        public static let strikethrough = Flags(rawValue: 1 << 5)
        public static let hidden = Flags(rawValue: 1 << 6)
    }

    public var foreground: TerminalColor = .standard
    public var background: TerminalColor = .standard
    public var flags: Flags = []

    public init() {}
}

public struct TerminalCell: Equatable, Sendable {
    public var character: Character = " "
    public var style = TerminalStyle()
    public var width: UInt8 = 1

    public init() {}
    public init(character: Character, style: TerminalStyle, width: UInt8 = 1) {
        self.character = character
        self.style = style
        self.width = width
    }
}

public struct TerminalLine: Equatable, Sendable {
    public var cells: [TerminalCell]
    public var wrapped = false

    public init(columns: Int, style: TerminalStyle = TerminalStyle()) {
        var blank = TerminalCell()
        blank.style.background = style.background
        cells = Array(repeating: blank, count: columns)
    }

    public var text: String {
        var s = ""
        for c in cells where c.width != 0 { s.append(c.character) }
        return s
    }

    public var trimmedText: String {
        var end = cells.count
        while end > 0, cells[end - 1].character == " " || cells[end - 1].width == 0 { end -= 1 }
        var s = ""
        for c in cells[..<end] where c.width != 0 { s.append(c.character) }
        return s
    }
}

public struct TerminalPosition: Equatable, Comparable, Sendable {
    public var line: Int
    public var column: Int
    public init(line: Int, column: Int) {
        self.line = line
        self.column = column
    }
    public static func < (a: Self, b: Self) -> Bool { (a.line, a.column) < (b.line, b.column) }
}

public enum TerminalCursorShape: Int, Codable, CaseIterable, Sendable {
    case block, underline, bar
    public var title: String {
        switch self {
        case .block: "Block"
        case .underline: "Underline"
        case .bar: "Bar"
        }
    }
}

public enum TerminalMouseMode: Sendable { case off, click, drag, motion }

public final class TerminalEmulator {
    public private(set) var columns: Int
    public private(set) var rows: Int
    public private(set) var scrollback: [TerminalLine] = []
    public var scrollbackLimit = 10000
    public private(set) var cursorX = 0
    public private(set) var cursorY = 0
    public private(set) var cursorVisible = true
    public private(set) var cursorShapeOverride: TerminalCursorShape?
    public private(set) var applicationCursorKeys = false
    public private(set) var applicationKeypad = false
    public private(set) var bracketedPaste = false
    public private(set) var usingAlternateScreen = false
    public private(set) var mouseMode: TerminalMouseMode = .off
    public private(set) var mouseSGR = false
    public private(set) var focusReporting = false
    public private(set) var title = ""
    public private(set) var workingDirectory: String?
    public private(set) var revision: UInt64 = 0
    public private(set) var scrollbackTrimmed = 0

    public var onResponse: ((String) -> Void)?
    public var onTitle: ((String) -> Void)?
    public var onBell: (() -> Void)?
    public var onWorkingDirectory: ((String) -> Void)?

    private var screen: [TerminalLine]
    private var savedPrimary: [TerminalLine]?
    private var style = TerminalStyle()
    private var scrollTop = 0
    private var scrollBottom: Int
    private var pendingWrap = false
    private var autowrap = true
    private var originMode = false
    private var insertMode = false
    private var newlineMode = false
    private var tabStops: Set<Int> = []
    private var lastPrinted: Character?

    private struct SavedCursor {
        var x = 0, y = 0
        var style = TerminalStyle()
        var originMode = false
        var charsets: [Bool] = [false, false]
        var activeCharset = 0
    }
    private var savedCursor = SavedCursor()
    private var savedCursorAlternate = SavedCursor()
    private var lineDrawing: [Bool] = [false, false]
    private var activeCharset = 0

    private enum State { case ground, escape, charset(Int), escapeIgnore, csi, osc, oscEscape, string, stringEscape }
    private var state = State.ground
    private var params: [Int] = []
    private var currentParam = -1
    private var csiPrefix: UInt8 = 0
    private var csiIntermediate: UInt8 = 0
    private var oscBuffer: [UInt8] = []
    private var utf8Remaining = 0
    private var utf8Scalar: UInt32 = 0

    public init(columns: Int = 80, rows: Int = 24) {
        self.columns = max(2, columns)
        self.rows = max(1, rows)
        scrollBottom = self.rows - 1
        screen = (0..<self.rows).map { _ in TerminalLine(columns: max(2, columns)) }
        resetTabStops()
    }

    public var totalLines: Int { scrollback.count + rows }

    public func line(_ index: Int) -> TerminalLine {
        if index < 0 { return TerminalLine(columns: columns) }
        if index < scrollback.count { return scrollback[index] }
        let i = index - scrollback.count
        return i < screen.count ? screen[i] : TerminalLine(columns: columns)
    }

    public var cursorLine: Int { scrollback.count + cursorY }

    public var screenText: String {
        screen.map(\.trimmedText).joined(separator: "\n")
    }

    public func text(from start: TerminalPosition, to end: TerminalPosition) -> String {
        guard start <= end else { return text(from: end, to: start) }
        var out = ""
        var index = max(0, start.line)
        let last = min(end.line, totalLines - 1)
        while index <= last {
            let l = line(index)
            let from = index == start.line ? max(0, start.column) : 0
            let to = index == end.line ? min(l.cells.count, end.column + 1) : l.cells.count
            if from < to {
                var piece = ""
                for c in l.cells[from..<to] where c.width != 0 { piece.append(c.character) }
                if index != end.line || to == l.cells.count {
                    while piece.hasSuffix(" ") { piece.removeLast() }
                }
                out += piece
            }
            if index != last && !l.wrapped { out += "\n" }
            index += 1
        }
        return out
    }

    public func clearScrollback() {
        scrollbackTrimmed += scrollback.count
        scrollback.removeAll()
        revision &+= 1
    }

    public func clearAll() {
        clearScrollback()
        let keep = screen[cursorY]
        for y in 0..<rows { screen[y] = TerminalLine(columns: columns) }
        screen[0] = keep
        cursorY = 0
        pendingWrap = false
        revision &+= 1
    }

    public func resize(columns newColumns: Int, rows newRows: Int) {
        let c = max(2, newColumns), r = max(1, newRows)
        guard c != columns || r != rows else { return }
        func fit(_ l: inout TerminalLine) {
            if l.cells.count > c {
                l.cells.removeLast(l.cells.count - c)
            } else if l.cells.count < c {
                l.cells.append(contentsOf: Array(repeating: TerminalCell(), count: c - l.cells.count))
            }
        }
        for i in screen.indices { fit(&screen[i]) }
        if var saved = savedPrimary {
            for i in saved.indices { fit(&saved[i]) }
            while saved.count > r { saved.removeFirst() }
            while saved.count < r { saved.append(TerminalLine(columns: c)) }
            savedPrimary = saved
        }
        if r < rows {
            var extra = rows - r
            while extra > 0, screen.count - 1 > cursorY, screen[screen.count - 1].trimmedText.isEmpty {
                screen.removeLast()
                extra -= 1
            }
            while extra > 0 {
                let top = screen.removeFirst()
                if !usingAlternateScreen { pushScrollback(top) }
                cursorY = max(0, cursorY - 1)
                extra -= 1
            }
        } else if r > rows {
            var extra = r - rows
            while extra > 0, !usingAlternateScreen, let last = scrollback.popLast() {
                var l = last
                fit(&l)
                screen.insert(l, at: 0)
                cursorY += 1
                extra -= 1
            }
            while extra > 0 {
                screen.append(TerminalLine(columns: c))
                extra -= 1
            }
        }
        columns = c
        rows = r
        scrollTop = 0
        scrollBottom = r - 1
        cursorX = min(cursorX, c - 1)
        cursorY = min(cursorY, r - 1)
        pendingWrap = false
        resetTabStops()
        revision &+= 1
    }

    private func resetTabStops() {
        tabStops = Set(stride(from: 8, to: max(columns, 9), by: 8))
    }

    private func pushScrollback(_ l: TerminalLine) {
        guard scrollbackLimit > 0 else { return }
        scrollback.append(l)
        if scrollback.count > scrollbackLimit {
            let drop = scrollback.count - scrollbackLimit
            scrollback.removeFirst(drop)
            scrollbackTrimmed += drop
        }
    }

    public func feed(_ data: Data) {
        data.withUnsafeBytes { raw in
            for b in raw { process(b) }
        }
        revision &+= 1
    }

    public func feed(_ string: String) { feed(Data(string.utf8)) }

    private func process(_ b: UInt8) {
        switch state {
        case .ground:
            if utf8Remaining > 0 {
                if b & 0xC0 == 0x80 {
                    utf8Scalar = (utf8Scalar << 6) | UInt32(b & 0x3F)
                    utf8Remaining -= 1
                    if utf8Remaining == 0 { put(Unicode.Scalar(utf8Scalar) ?? "\u{FFFD}") }
                    return
                }
                utf8Remaining = 0
                put("\u{FFFD}")
            }
            if b < 0x20 || b == 0x7F {
                control(b)
            } else if b < 0x80 {
                put(Unicode.Scalar(b))
            } else if b & 0xE0 == 0xC0 {
                utf8Scalar = UInt32(b & 0x1F); utf8Remaining = 1
            } else if b & 0xF0 == 0xE0 {
                utf8Scalar = UInt32(b & 0x0F); utf8Remaining = 2
            } else if b & 0xF8 == 0xF0 {
                utf8Scalar = UInt32(b & 0x07); utf8Remaining = 3
            } else {
                put("\u{FFFD}")
            }
        case .escape:
            escape(b)
        case .charset(let slot):
            lineDrawing[slot] = b == 0x30
            state = .ground
        case .escapeIgnore:
            state = .ground
        case .csi:
            csi(b)
        case .osc:
            if b == 0x07 {
                finishOSC()
            } else if b == 0x1B {
                state = .oscEscape
            } else if oscBuffer.count < 4096 {
                oscBuffer.append(b)
            }
        case .oscEscape:
            finishOSC()
            if b != 0x5C { state = .escape; escape(b) }
        case .string:
            if b == 0x1B { state = .stringEscape } else if b == 0x07 { state = .ground }
        case .stringEscape:
            if b == 0x5C { state = .ground } else { state = .string }
        }
    }

    private func control(_ b: UInt8) {
        switch b {
        case 0x07: onBell?()
        case 0x08:
            if cursorX > 0 { cursorX -= 1 }
            pendingWrap = false
        case 0x09: tab()
        case 0x0A, 0x0B, 0x0C:
            lineFeed()
            if newlineMode { cursorX = 0 }
        case 0x0D:
            cursorX = 0
            pendingWrap = false
        case 0x0E: activeCharset = 1
        case 0x0F: activeCharset = 0
        case 0x1B: state = .escape
        default: break
        }
    }

    private func tab() {
        var x = cursorX + 1
        while x < columns - 1, !tabStops.contains(x) { x += 1 }
        cursorX = min(x, columns - 1)
        pendingWrap = false
    }

    private func backTab() {
        var x = cursorX - 1
        while x > 0, !tabStops.contains(x) { x -= 1 }
        cursorX = max(0, x)
        pendingWrap = false
    }

    private func lineFeed() {
        pendingWrap = false
        if cursorY == scrollBottom {
            scrollUp(1)
        } else if cursorY < rows - 1 {
            cursorY += 1
        }
    }

    private func reverseIndex() {
        pendingWrap = false
        if cursorY == scrollTop {
            scrollDown(1)
        } else if cursorY > 0 {
            cursorY -= 1
        }
    }

    private func scrollUp(_ n: Int) {
        let count = min(max(n, 1), scrollBottom - scrollTop + 1)
        for _ in 0..<count {
            let removed = screen.remove(at: scrollTop)
            if scrollTop == 0 && !usingAlternateScreen { pushScrollback(removed) }
            screen.insert(TerminalLine(columns: columns, style: style), at: scrollBottom)
        }
    }

    private func scrollDown(_ n: Int) {
        let count = min(max(n, 1), scrollBottom - scrollTop + 1)
        for _ in 0..<count {
            screen.remove(at: scrollBottom)
            screen.insert(TerminalLine(columns: columns, style: style), at: scrollTop)
        }
    }

    private static let lineDrawingMap: [UInt8: Character] = [
        0x60: "◆", 0x61: "▒", 0x66: "°", 0x67: "±", 0x6A: "┘", 0x6B: "┐", 0x6C: "┌", 0x6D: "└", 0x6E: "┼",
        0x6F: "⎺", 0x70: "⎻", 0x71: "─", 0x72: "⎼", 0x73: "⎽", 0x74: "├", 0x75: "┤", 0x76: "┴", 0x77: "┬",
        0x78: "│", 0x79: "≤", 0x7A: "≥", 0x7B: "π", 0x7C: "≠", 0x7D: "£", 0x7E: "·",
    ]

    public static func width(of scalar: Unicode.Scalar) -> Int {
        let v = scalar.value
        if v < 0x300 { return 1 }
        if v == 0x200D || (0xFE00...0xFE0F).contains(v) || (0xE0100...0xE01EF).contains(v) || (0x1F3FB...0x1F3FF).contains(v) { return 0 }
        switch scalar.properties.generalCategory {
        case .nonspacingMark, .enclosingMark, .format: return 0
        default: break
        }
        if (0x1100...0x115F).contains(v) || (0x2E80...0x303E).contains(v) || (0x3041...0x33FF).contains(v) || (0x3400...0x4DBF).contains(v)
            || (0x4E00...0x9FFF).contains(v) || (0xA000...0xA4CF).contains(v) || (0xAC00...0xD7A3).contains(v) || (0xF900...0xFAFF).contains(v)
            || (0xFE30...0xFE4F).contains(v) || (0xFF00...0xFF60).contains(v) || (0xFFE0...0xFFE6).contains(v) || (0x1F300...0x1F64F).contains(v)
            || (0x1F900...0x1F9FF).contains(v) || (0x1F680...0x1F6FF).contains(v) || (0x1FA70...0x1FAFF).contains(v) || (0x20000...0x3FFFD).contains(v) {
            return 2
        }
        return 1
    }

    private func put(_ scalar: Unicode.Scalar) {
        var ch = Character(scalar)
        if lineDrawing[activeCharset], scalar.value < 0x80, let mapped = Self.lineDrawingMap[UInt8(scalar.value)] { ch = mapped }
        let w = Self.width(of: scalar)
        if w == 0 {
            let x = pendingWrap ? cursorX : cursorX - 1
            guard x >= 0 else { return }
            var target = x
            if screen[cursorY].cells[target].width == 0, target > 0 { target -= 1 }
            var s = String(screen[cursorY].cells[target].character)
            s.unicodeScalars.append(scalar)
            if let merged = s.first, s.count == 1 { screen[cursorY].cells[target].character = merged }
            return
        }
        if pendingWrap {
            if autowrap {
                screen[cursorY].wrapped = true
                cursorX = 0
                lineFeed()
            }
            pendingWrap = false
        }
        if w == 2 && cursorX == columns - 1 {
            if autowrap {
                screen[cursorY].wrapped = true
                cursorX = 0
                lineFeed()
            } else {
                return
            }
        }
        if insertMode {
            let blank = Array(repeating: TerminalCell(), count: w)
            screen[cursorY].cells.insert(contentsOf: blank, at: cursorX)
            screen[cursorY].cells.removeLast(w)
        }
        clearWide(at: cursorX)
        screen[cursorY].cells[cursorX] = TerminalCell(character: ch, style: style, width: UInt8(w))
        if w == 2 {
            clearWide(at: cursorX + 1)
            screen[cursorY].cells[cursorX + 1] = TerminalCell(character: " ", style: style, width: 0)
        }
        lastPrinted = ch
        if cursorX + w >= columns {
            cursorX = columns - 1
            pendingWrap = true
        } else {
            cursorX += w
        }
    }

    private func clearWide(at x: Int) {
        let cell = screen[cursorY].cells[x]
        if cell.width == 0, x > 0 {
            screen[cursorY].cells[x - 1].character = " "
            screen[cursorY].cells[x - 1].width = 1
        } else if cell.width == 2, x + 1 < columns {
            screen[cursorY].cells[x + 1].width = 1
        }
    }

    private func escape(_ b: UInt8) {
        state = .ground
        switch b {
        case 0x5B:
            params = []
            currentParam = -1
            csiPrefix = 0
            csiIntermediate = 0
            state = .csi
        case 0x5D:
            oscBuffer = []
            state = .osc
        case 0x50, 0x58, 0x5E, 0x5F: state = .string
        case 0x28: state = .charset(0)
        case 0x29: state = .charset(1)
        case 0x2A, 0x2B, 0x23, 0x25, 0x20: state = .escapeIgnore
        case 0x37: saveCursor()
        case 0x38: restoreCursor()
        case 0x44: lineFeed()
        case 0x45:
            cursorX = 0
            lineFeed()
        case 0x48: tabStops.insert(cursorX)
        case 0x4D: reverseIndex()
        case 0x3D: applicationKeypad = true
        case 0x3E: applicationKeypad = false
        case 0x63: fullReset()
        default: break
        }
    }

    private func fullReset() {
        style = TerminalStyle()
        usingAlternateScreen = false
        savedPrimary = nil
        screen = (0..<rows).map { _ in TerminalLine(columns: columns) }
        cursorX = 0
        cursorY = 0
        scrollTop = 0
        scrollBottom = rows - 1
        pendingWrap = false
        autowrap = true
        originMode = false
        insertMode = false
        cursorVisible = true
        applicationCursorKeys = false
        applicationKeypad = false
        bracketedPaste = false
        mouseMode = .off
        mouseSGR = false
        lineDrawing = [false, false]
        activeCharset = 0
        cursorShapeOverride = nil
        resetTabStops()
    }

    private func saveCursor() {
        let s = SavedCursor(x: cursorX, y: cursorY, style: style, originMode: originMode, charsets: lineDrawing, activeCharset: activeCharset)
        if usingAlternateScreen { savedCursorAlternate = s } else { savedCursor = s }
    }

    private func restoreCursor() {
        let s = usingAlternateScreen ? savedCursorAlternate : savedCursor
        cursorX = min(s.x, columns - 1)
        cursorY = min(s.y, rows - 1)
        style = s.style
        originMode = s.originMode
        lineDrawing = s.charsets
        activeCharset = s.activeCharset
        pendingWrap = false
    }

    private func finishOSC() {
        state = .ground
        let text = String(decoding: oscBuffer, as: UTF8.self)
        oscBuffer = []
        guard let semi = text.firstIndex(of: ";") else { return }
        let code = text[..<semi]
        let value = String(text[text.index(after: semi)...])
        switch code {
        case "0", "2":
            title = value
            onTitle?(value)
        case "7":
            if let url = URL(string: value), url.isFileURL {
                workingDirectory = url.path
                onWorkingDirectory?(url.path)
            }
        default: break
        }
    }

    private func csi(_ b: UInt8) {
        switch b {
        case 0x30...0x39:
            currentParam = (currentParam < 0 ? 0 : min(currentParam, 99999) * 10) + Int(b - 0x30)
        case 0x3B, 0x3A:
            params.append(currentParam)
            currentParam = -1
        case 0x3C...0x3F:
            csiPrefix = b
        case 0x20...0x2F:
            csiIntermediate = b
        case 0x40...0x7E:
            params.append(currentParam)
            state = .ground
            dispatchCSI(b)
        case 0x1B:
            state = .escape
        case 0x00...0x1F:
            control(b)
        default:
            state = .ground
        }
    }

    private func param(_ i: Int, _ fallback: Int) -> Int {
        i < params.count && params[i] > 0 ? params[i] : fallback
    }

    private func moveCursor(x: Int, y: Int) {
        cursorX = min(max(0, x), columns - 1)
        let top = originMode ? scrollTop : 0
        let bottom = originMode ? scrollBottom : rows - 1
        cursorY = min(max(top, y), bottom)
        pendingWrap = false
    }

    private func blank() -> TerminalCell {
        var c = TerminalCell()
        c.style.background = style.background
        return c
    }

    private func erase(line y: Int, from: Int, to: Int) {
        guard from < to else { return }
        let b = blank()
        for x in max(0, from)..<min(columns, to) { screen[y].cells[x] = b }
        if to >= columns { screen[y].wrapped = false }
    }

    private func dispatchCSI(_ final: UInt8) {
        if csiPrefix == 0x3F {
            switch final {
            case 0x68: for p in params where p >= 0 { setPrivateMode(p, true) }
            case 0x6C: for p in params where p >= 0 { setPrivateMode(p, false) }
            case 0x6E where param(0, 0) == 6: onResponse?("\u{1B}[?\(cursorY + 1);\(cursorX + 1)R")
            default: break
            }
            return
        }
        if csiPrefix == 0x3E {
            if final == 0x63 { onResponse?("\u{1B}[>0;276;0c") }
            return
        }
        if csiPrefix != 0 { return }
        if csiIntermediate == 0x20 {
            if final == 0x71 {
                switch param(0, 0) {
                case 0: cursorShapeOverride = nil
                case 1, 2: cursorShapeOverride = .block
                case 3, 4: cursorShapeOverride = .underline
                default: cursorShapeOverride = .bar
                }
            }
            return
        }
        if csiIntermediate == 0x21 {
            if final == 0x70 {
                style = TerminalStyle()
                insertMode = false
                originMode = false
                autowrap = true
                cursorVisible = true
                scrollTop = 0
                scrollBottom = rows - 1
            }
            return
        }
        if csiIntermediate != 0 { return }
        switch final {
        case 0x41: moveCursorClamped(dy: -param(0, 1))
        case 0x42, 0x65: moveCursorClamped(dy: param(0, 1))
        case 0x43, 0x61:
            cursorX = min(columns - 1, cursorX + param(0, 1))
            pendingWrap = false
        case 0x44:
            cursorX = max(0, cursorX - param(0, 1))
            pendingWrap = false
        case 0x45:
            moveCursorClamped(dy: param(0, 1))
            cursorX = 0
        case 0x46:
            moveCursorClamped(dy: -param(0, 1))
            cursorX = 0
        case 0x47, 0x60:
            cursorX = min(columns - 1, param(0, 1) - 1)
            pendingWrap = false
        case 0x48, 0x66:
            moveCursor(x: param(1, 1) - 1, y: param(0, 1) - 1 + (originMode ? scrollTop : 0))
        case 0x49:
            for _ in 0..<param(0, 1) { tab() }
        case 0x4A: eraseDisplay(param(0, 0))
        case 0x4B:
            switch param(0, 0) {
            case 0: erase(line: cursorY, from: cursorX, to: columns)
            case 1: erase(line: cursorY, from: 0, to: cursorX + 1)
            default: erase(line: cursorY, from: 0, to: columns)
            }
            pendingWrap = false
        case 0x4C:
            guard cursorY >= scrollTop, cursorY <= scrollBottom else { return }
            for _ in 0..<min(param(0, 1), scrollBottom - cursorY + 1) {
                screen.remove(at: scrollBottom)
                screen.insert(TerminalLine(columns: columns, style: style), at: cursorY)
            }
            cursorX = 0
            pendingWrap = false
        case 0x4D:
            guard cursorY >= scrollTop, cursorY <= scrollBottom else { return }
            for _ in 0..<min(param(0, 1), scrollBottom - cursorY + 1) {
                screen.remove(at: cursorY)
                screen.insert(TerminalLine(columns: columns, style: style), at: scrollBottom)
            }
            cursorX = 0
            pendingWrap = false
        case 0x50:
            let n = min(param(0, 1), columns - cursorX)
            screen[cursorY].cells.removeSubrange(cursorX..<cursorX + n)
            screen[cursorY].cells.append(contentsOf: Array(repeating: blank(), count: n))
            pendingWrap = false
        case 0x40:
            let n = min(param(0, 1), columns - cursorX)
            screen[cursorY].cells.insert(contentsOf: Array(repeating: blank(), count: n), at: cursorX)
            screen[cursorY].cells.removeLast(n)
            pendingWrap = false
        case 0x58:
            erase(line: cursorY, from: cursorX, to: min(columns, cursorX + param(0, 1)))
            pendingWrap = false
        case 0x53: scrollUp(param(0, 1))
        case 0x54: scrollDown(param(0, 1))
        case 0x5A:
            for _ in 0..<param(0, 1) { backTab() }
        case 0x62:
            if let c = lastPrinted {
                for _ in 0..<min(param(0, 1), columns * rows) {
                    for s in c.unicodeScalars { put(s) }
                }
            }
        case 0x63:
            if param(0, 0) == 0 { onResponse?("\u{1B}[?62;22c") }
        case 0x64:
            moveCursor(x: cursorX, y: param(0, 1) - 1 + (originMode ? scrollTop : 0))
        case 0x67:
            if param(0, 0) == 3 { tabStops.removeAll() } else { tabStops.remove(cursorX) }
        case 0x68, 0x6C:
            let on = final == 0x68
            for p in params {
                if p == 4 { insertMode = on }
                if p == 20 { newlineMode = on }
            }
        case 0x6D: selectGraphicRendition()
        case 0x6E:
            switch param(0, 0) {
            case 5: onResponse?("\u{1B}[0n")
            case 6: onResponse?("\u{1B}[\(cursorY - (originMode ? scrollTop : 0) + 1);\(cursorX + 1)R")
            default: break
            }
        case 0x72:
            let top = param(0, 1) - 1
            let bottom = param(1, rows) - 1
            if top < bottom, bottom < rows {
                scrollTop = top
                scrollBottom = bottom
            } else {
                scrollTop = 0
                scrollBottom = rows - 1
            }
            moveCursor(x: 0, y: originMode ? scrollTop : 0)
        case 0x73: saveCursor()
        case 0x75: restoreCursor()
        case 0x74:
            switch param(0, 0) {
            case 18: onResponse?("\u{1B}[8;\(rows);\(columns)t")
            default: break
            }
        default: break
        }
    }

    private func moveCursorClamped(dy: Int) {
        let top = cursorY >= scrollTop ? scrollTop : 0
        let bottom = cursorY <= scrollBottom ? scrollBottom : rows - 1
        cursorY = min(max(top, cursorY + dy), bottom)
        pendingWrap = false
    }

    private func eraseDisplay(_ mode: Int) {
        switch mode {
        case 0:
            erase(line: cursorY, from: cursorX, to: columns)
            if cursorY + 1 < rows { for y in (cursorY + 1)..<rows { erase(line: y, from: 0, to: columns) } }
        case 1:
            for y in 0..<cursorY { erase(line: y, from: 0, to: columns) }
            erase(line: cursorY, from: 0, to: cursorX + 1)
        case 2:
            if !usingAlternateScreen {
                var last = rows - 1
                while last >= 0, screen[last].trimmedText.isEmpty { last -= 1 }
                if last >= 0 { for y in 0...last { pushScrollback(screen[y]) } }
            }
            for y in 0..<rows { erase(line: y, from: 0, to: columns) }
        case 3:
            scrollbackTrimmed += scrollback.count
            scrollback.removeAll()
        default: break
        }
        pendingWrap = false
    }

    private func setPrivateMode(_ mode: Int, _ on: Bool) {
        switch mode {
        case 1: applicationCursorKeys = on
        case 6:
            originMode = on
            moveCursor(x: 0, y: on ? scrollTop : 0)
        case 7: autowrap = on
        case 25: cursorVisible = on
        case 47, 1047: switchScreen(alternate: on, saveCursor: false)
        case 1048: if on { saveCursor() } else { restoreCursor() }
        case 1049: switchScreen(alternate: on, saveCursor: true)
        case 9, 1000: mouseMode = on ? .click : .off
        case 1002: mouseMode = on ? .drag : .off
        case 1003: mouseMode = on ? .motion : .off
        case 1004: focusReporting = on
        case 1006: mouseSGR = on
        case 2004: bracketedPaste = on
        default: break
        }
    }

    private func switchScreen(alternate: Bool, saveCursor save: Bool) {
        guard alternate != usingAlternateScreen else { return }
        if alternate {
            if save { saveCursor() }
            savedPrimary = screen
            usingAlternateScreen = true
            screen = (0..<rows).map { _ in TerminalLine(columns: columns) }
        } else {
            usingAlternateScreen = false
            if let saved = savedPrimary { screen = saved }
            savedPrimary = nil
            if save { restoreCursor() }
        }
        scrollTop = 0
        scrollBottom = rows - 1
        pendingWrap = false
    }

    private func selectGraphicRendition() {
        var i = 0
        if params.isEmpty { style = TerminalStyle(); return }
        while i < params.count {
            let p = max(params[i], 0)
            switch p {
            case 0: style = TerminalStyle()
            case 1: style.flags.insert(.bold)
            case 2: style.flags.insert(.dim)
            case 3: style.flags.insert(.italic)
            case 4: style.flags.insert(.underline)
            case 7: style.flags.insert(.inverse)
            case 8: style.flags.insert(.hidden)
            case 9: style.flags.insert(.strikethrough)
            case 21: style.flags.insert(.underline)
            case 22: style.flags.subtract([.bold, .dim])
            case 23: style.flags.remove(.italic)
            case 24: style.flags.remove(.underline)
            case 27: style.flags.remove(.inverse)
            case 28: style.flags.remove(.hidden)
            case 29: style.flags.remove(.strikethrough)
            case 30...37: style.foreground = .indexed(UInt8(p - 30))
            case 39: style.foreground = .standard
            case 40...47: style.background = .indexed(UInt8(p - 40))
            case 49: style.background = .standard
            case 90...97: style.foreground = .indexed(UInt8(p - 90 + 8))
            case 100...107: style.background = .indexed(UInt8(p - 100 + 8))
            case 38, 48:
                var color: TerminalColor?
                if i + 2 < params.count, params[i + 1] == 5 {
                    color = .indexed(UInt8(clamping: max(params[i + 2], 0)))
                    i += 2
                } else if i + 1 < params.count, params[i + 1] == 2 {
                    var first = i + 2
                    if first < params.count, params[first] < 0, params.count - first >= 4 { first += 1 }
                    if first + 2 < params.count {
                        color = .rgb(UInt8(clamping: max(params[first], 0)), UInt8(clamping: max(params[first + 1], 0)),
                                     UInt8(clamping: max(params[first + 2], 0)))
                    }
                    i = min(params.count - 1, first + 2)
                }
                if let color {
                    if p == 38 { style.foreground = color } else { style.background = color }
                }
            default: break
            }
            i += 1
        }
    }
}
