import AppKit

public enum TerminalViewCommand {
    case newTab, closePane, split, clear, find, nextTab, previousTab, biggerFont, smallerFont, resetFont
}

@MainActor
public final class TerminalScreenView: NSView, @preconcurrency NSTextInputClient, NSMenuItemValidation {
    public let emulator: TerminalEmulator
    public var settings: TerminalSettings { didSet { if settings != oldValue { applySettings() } } }
    public var onInput: ((Data) -> Void)?
    public var onResize: ((Int, Int) -> Void)?
    public var onOpenPath: ((String, Int?) -> Bool)?
    public var onCommand: ((TerminalViewCommand) -> Bool)?
    public var onFocus: (() -> Void)?
    public var currentDirectory: (() -> String?)?
    public var contextMenuItems: (() -> [NSMenuItem])?

    public private(set) var cellSize = NSSize(width: 7, height: 15)
    public private(set) var scrollOffset = 0
    public private(set) var theme = TerminalTheme.dark

    private var font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    private var boldFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .bold)
    private var italicFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    private var boldItalicFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .bold)
    private var baseline: CGFloat = 3
    private var colorCache: [UInt32: NSColor] = [:]
    private let scroller = NSScroller()
    private var selectionAnchor: TerminalPosition?
    private var selectionHead: TerminalPosition?
    private var selectionMode = 1
    private var blinkOn = true
    private var blinkTimer: Timer?
    private var wheelRemainder: CGFloat = 0
    private var markedText = ""
    private var lastRevision: UInt64 = 0
    private var searchQuery = ""
    private var searchMatches: [(line: Int, column: Int, length: Int)] = []
    private var searchRevision: UInt64 = .max
    private var searchIndex = -1
    private var mouseReportedButton: Int?

    static let inset = NSSize(width: 6, height: 4)

    public init(emulator: TerminalEmulator, settings: TerminalSettings) {
        self.emulator = emulator
        self.settings = settings
        super.init(frame: NSRect(x: 0, y: 0, width: 640, height: 240))
        scroller.scrollerStyle = .overlay
        scroller.controlSize = .small
        scroller.target = self
        scroller.action = #selector(scrollerMoved(_:))
        scroller.isHidden = true
        addSubview(scroller)
        setAccessibilityRole(.textArea)
        setAccessibilityLabel("Terminal")
        applySettings()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    public override var isFlipped: Bool { true }
    public override var acceptsFirstResponder: Bool { true }
    public override var isOpaque: Bool { true }
    public override func accessibilityValue() -> Any? { emulator.screenText }

    public override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applySettings()
    }

    private func applySettings() {
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        theme = TerminalTheme.theme(id: settings.themeID, darkAppearance: dark)
        colorCache.removeAll()
        font = settings.font
        let manager = NSFontManager.shared
        boldFont = manager.convert(font, toHaveTrait: .boldFontMask)
        italicFont = manager.convert(font, toHaveTrait: .italicFontMask)
        boldItalicFont = manager.convert(boldFont, toHaveTrait: .italicFontMask)
        let advance = ("W" as NSString).size(withAttributes: [.font: font]).width
        let height = ceil(font.ascender - font.descender + font.leading)
        cellSize = NSSize(width: max(1, ceil(advance * 100) / 100), height: max(1, height))
        baseline = ceil(-font.descender)
        emulator.scrollbackLimit = settings.scrollbackLines
        restartBlink()
        recalculateGrid()
        needsDisplay = true
    }

    private func color(_ rgb: UInt32) -> NSColor {
        if let c = colorCache[rgb] { return c }
        let c = NSColor(srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255, green: CGFloat((rgb >> 8) & 0xFF) / 255, blue: CGFloat(rgb & 0xFF) / 255, alpha: 1)
        colorCache[rgb] = c
        return c
    }

    public var visibleColumns: Int { emulator.columns }
    public var visibleRows: Int { emulator.rows }

    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        scroller.frame = NSRect(x: newSize.width - 12, y: 0, width: 12, height: newSize.height)
        recalculateGrid()
    }

    private func recalculateGrid() {
        let usableWidth = bounds.width - Self.inset.width * 2
        let usableHeight = bounds.height - Self.inset.height * 2
        guard usableWidth >= cellSize.width * 8, usableHeight >= cellSize.height * 2 else { return }
        let columns = Int(usableWidth / cellSize.width)
        let rows = Int(usableHeight / cellSize.height)
        guard columns != emulator.columns || rows != emulator.rows else { return }
        emulator.resize(columns: columns, rows: rows)
        scrollOffset = min(scrollOffset, emulator.scrollback.count)
        onResize?(emulator.columns, emulator.rows)
        updateScroller()
        needsDisplay = true
    }

    public func contentDidChange() {
        guard emulator.revision != lastRevision else { return }
        lastRevision = emulator.revision
        scrollOffset = min(scrollOffset, emulator.scrollback.count)
        blinkOn = true
        updateScroller()
        needsDisplay = true
    }

    public func scrollToBottom() {
        guard scrollOffset != 0 else { return }
        scrollOffset = 0
        updateScroller()
        needsDisplay = true
    }

    private func setScrollOffset(_ value: Int) {
        let clamped = min(max(0, value), emulator.scrollback.count)
        guard clamped != scrollOffset else { return }
        scrollOffset = clamped
        updateScroller()
        needsDisplay = true
    }

    private func updateScroller() {
        let history = emulator.scrollback.count
        scroller.isHidden = history == 0 || emulator.usingAlternateScreen
        guard history > 0 else { return }
        scroller.knobProportion = CGFloat(emulator.rows) / CGFloat(history + emulator.rows)
        scroller.doubleValue = 1 - Double(scrollOffset) / Double(history)
    }

    @objc private func scrollerMoved(_ sender: NSScroller) {
        let history = emulator.scrollback.count
        switch sender.hitPart {
        case .decrementPage: setScrollOffset(scrollOffset + emulator.rows)
        case .incrementPage: setScrollOffset(scrollOffset - emulator.rows)
        default: setScrollOffset(Int((Double(history) * (1 - sender.doubleValue)).rounded()))
        }
    }

    private var topLine: Int { emulator.scrollback.count - scrollOffset }

    private func stable(_ p: TerminalPosition) -> TerminalPosition { TerminalPosition(line: p.line + emulator.scrollbackTrimmed, column: p.column) }
    private func live(_ p: TerminalPosition) -> TerminalPosition { TerminalPosition(line: p.line - emulator.scrollbackTrimmed, column: p.column) }

    public var selectionRange: (start: TerminalPosition, end: TerminalPosition)? {
        guard let a = selectionAnchor, let h = selectionHead else { return nil }
        let (s, e) = a <= h ? (live(a), live(h)) : (live(h), live(a))
        guard e.line >= 0 else { return nil }
        return (TerminalPosition(line: max(0, s.line), column: s.line < 0 ? 0 : s.column), e)
    }

    public var selectedText: String? {
        guard let r = selectionRange else { return nil }
        let text = emulator.text(from: r.start, to: r.end)
        return text.isEmpty ? nil : text
    }

    public func clearSelection() {
        guard selectionAnchor != nil else { return }
        selectionAnchor = nil
        selectionHead = nil
        needsDisplay = true
    }

    public override func draw(_ dirtyRect: NSRect) {
        color(theme.background).setFill()
        bounds.fill()
        let selection = selectionRange
        let first = topLine
        for row in 0..<emulator.rows {
            let y = Self.inset.height + CGFloat(row) * cellSize.height
            guard NSRect(x: 0, y: y, width: bounds.width, height: cellSize.height).intersects(dirtyRect) else { continue }
            let index = first + row
            drawLine(emulator.line(index), index: index, y: y, selection: selection)
        }
        drawCursor()
        if !markedText.isEmpty {
            let x = Self.inset.width + CGFloat(emulator.cursorX) * cellSize.width
            let y = Self.inset.height + CGFloat(emulator.cursorY + scrollOffset) * cellSize.height
            let s = NSAttributedString(string: markedText, attributes: [
                .font: font, .foregroundColor: color(theme.foreground), .backgroundColor: color(theme.selection),
                .underlineStyle: NSUnderlineStyle.single.rawValue,
            ])
            s.draw(at: NSPoint(x: x, y: y))
        }
    }

    private func resolved(_ style: TerminalStyle, selected: Bool) -> (fg: UInt32, bg: UInt32) {
        var fg = theme.rgb(style.foreground, foreground: true, bold: style.flags.contains(.bold))
        var bg = theme.rgb(style.background, foreground: false)
        if style.flags.contains(.inverse) { swap(&fg, &bg) }
        if style.flags.contains(.dim) { fg = Self.blend(fg, bg, 0.5) }
        if style.flags.contains(.hidden) { fg = bg }
        if selected { bg = theme.selection }
        return (fg, bg)
    }

    static func blend(_ a: UInt32, _ b: UInt32, _ t: Double) -> UInt32 {
        func mix(_ shift: UInt32) -> UInt32 {
            let x = Double((a >> shift) & 0xFF), y = Double((b >> shift) & 0xFF)
            return UInt32(x + (y - x) * t) << shift
        }
        return mix(16) | mix(8) | mix(0)
    }

    private func drawLine(_ line: TerminalLine, index: Int, y: CGFloat, selection: (start: TerminalPosition, end: TerminalPosition)?) {
        let count = min(line.cells.count, emulator.columns)
        guard count > 0 else { return }
        func isSelected(_ x: Int) -> Bool {
            guard let s = selection else { return false }
            let p = TerminalPosition(line: index, column: x)
            return p >= s.start && p <= s.end
        }
        var x = 0
        while x < count {
            let (_, bg) = resolved(line.cells[x].style, selected: isSelected(x))
            var end = x + 1
            while end < count, resolved(line.cells[end].style, selected: isSelected(end)).bg == bg { end += 1 }
            if bg != theme.background {
                color(bg).setFill()
                NSRect(x: Self.inset.width + CGFloat(x) * cellSize.width, y: y, width: CGFloat(end - x) * cellSize.width, height: cellSize.height).fill()
            }
            x = end
        }
        for m in searchMatches where m.line == index {
            let current = searchIndex >= 0 && searchIndex < searchMatches.count && searchMatches[searchIndex] == m
            (current ? NSColor.systemOrange.withAlphaComponent(0.75) : NSColor.systemYellow.withAlphaComponent(0.4)).setFill()
            NSRect(x: Self.inset.width + CGFloat(m.column) * cellSize.width, y: y, width: CGFloat(m.length) * cellSize.width, height: cellSize.height).fill()
        }
        x = 0
        while x < count {
            let cell = line.cells[x]
            if cell.width == 0 || (cell.character == " " && cell.style.flags.isDisjoint(with: [.underline, .strikethrough])) {
                x += 1
                continue
            }
            let selected = isSelected(x)
            let fg = resolved(cell.style, selected: selected).fg
            var text = String(cell.character)
            var end = x + 1
            if cell.character.isASCII {
                while end < count, line.cells[end].style == cell.style, line.cells[end].character.isASCII, line.cells[end].width == 1,
                      isSelected(end) == selected {
                    text.append(line.cells[end].character)
                    end += 1
                }
            }
            let bold = cell.style.flags.contains(.bold), italic = cell.style.flags.contains(.italic)
            var attributes: [NSAttributedString.Key: Any] = [
                .font: bold ? (italic ? boldItalicFont : boldFont) : (italic ? italicFont : font),
                .foregroundColor: color(fg),
            ]
            if cell.style.flags.contains(.underline) { attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
            if cell.style.flags.contains(.strikethrough) { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
            NSAttributedString(string: text, attributes: attributes).draw(at: NSPoint(x: Self.inset.width + CGFloat(x) * cellSize.width, y: y))
            x = end
        }
    }

    private var isFocused: Bool { window?.firstResponder === self && window?.isKeyWindow == true }

    private func drawCursor() {
        guard emulator.cursorVisible else { return }
        let row = emulator.cursorY + scrollOffset
        guard row < emulator.rows else { return }
        let rect = NSRect(x: Self.inset.width + CGFloat(emulator.cursorX) * cellSize.width, y: Self.inset.height + CGFloat(row) * cellSize.height,
                          width: cellSize.width, height: cellSize.height)
        let cursorColor = color(theme.cursor)
        guard isFocused else {
            cursorColor.setStroke()
            NSBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5)).stroke()
            return
        }
        guard blinkOn || !settings.cursorBlink else { return }
        cursorColor.setFill()
        switch emulator.cursorShapeOverride ?? settings.cursorShape {
        case .block:
            rect.fill()
            let cell = emulator.line(emulator.cursorLine).cells[min(emulator.cursorX, emulator.columns - 1)]
            if cell.character != " ", cell.width != 0 {
                NSAttributedString(string: String(cell.character), attributes: [.font: font, .foregroundColor: color(theme.background)])
                    .draw(at: rect.origin)
            }
        case .underline: NSRect(x: rect.minX, y: rect.maxY - 2, width: rect.width, height: 2).fill()
        case .bar: NSRect(x: rect.minX, y: rect.minY, width: 2, height: rect.height).fill()
        }
    }

    private func restartBlink() {
        blinkTimer?.invalidate()
        blinkTimer = nil
        blinkOn = true
        guard settings.cursorBlink, window != nil else { return }
        let timer = Timer(timeInterval: 0.6, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isFocused, self.emulator.cursorVisible else { return }
                self.blinkOn.toggle()
                self.setNeedsDisplay(self.cursorRect)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        blinkTimer = timer
    }

    private var cursorRect: NSRect {
        NSRect(x: Self.inset.width + CGFloat(emulator.cursorX) * cellSize.width - 1,
               y: Self.inset.height + CGFloat(emulator.cursorY + scrollOffset) * cellSize.height - 1, width: cellSize.width * 2 + 2, height: cellSize.height + 2)
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        restartBlink()
        NotificationCenter.default.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: nil)
        guard let window else { return }
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification] {
            NotificationCenter.default.addObserver(self, selector: #selector(windowKeyChanged(_:)), name: name, object: window)
        }
    }

    @objc private func windowKeyChanged(_ note: Notification) { needsDisplay = true }

    public override func becomeFirstResponder() -> Bool {
        blinkOn = true
        needsDisplay = true
        if emulator.focusReporting { send("\u{1B}[I") }
        onFocus?()
        return true
    }

    public override func resignFirstResponder() -> Bool {
        needsDisplay = true
        if emulator.focusReporting { send("\u{1B}[O") }
        return true
    }

    public func send(_ string: String) {
        guard !string.isEmpty else { return }
        onInput?(Data(string.utf8))
    }

    private func userInput(_ string: String) {
        scrollToBottom()
        blinkOn = true
        send(string)
    }

    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard window?.firstResponder === self else { return super.performKeyEquivalent(with: event) }
        let mods = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard mods.contains(.command), !mods.contains(.control), !mods.contains(.option) else { return super.performKeyEquivalent(with: event) }
        let shift = mods.contains(.shift)
        let command: TerminalViewCommand?
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "t" where !shift: command = .newTab
        case "w" where !shift: command = .closePane
        case "d" where !shift: command = .split
        case "k" where !shift: command = .clear
        case "f" where !shift: command = .find
        case "]" where shift, "}": command = .nextTab
        case "[" where shift, "{": command = .previousTab
        case "=", "+": command = .biggerFont
        case "-" where !shift: command = .smallerFont
        case "0" where !shift: command = .resetFont
        default: command = nil
        }
        if let command, onCommand?(command) == true { return true }
        return super.performKeyEquivalent(with: event)
    }

    public override func keyDown(with event: NSEvent) {
        let mods = event.modifierFlags.intersection([.command, .shift, .option, .control])
        if hasMarkedText() {
            interpretKeyEvents([event])
            return
        }
        if let sequence = specialSequence(event, mods) {
            userInput(sequence)
            return
        }
        if mods.contains(.command) {
            super.keyDown(with: event)
            return
        }
        if mods.contains(.control), let scalar = event.charactersIgnoringModifiers?.unicodeScalars.first, let code = Self.controlCode(scalar) {
            userInput((mods.contains(.option) ? "\u{1B}" : "") + String(UnicodeScalar(code)))
            return
        }
        if mods.contains(.option), settings.optionAsMeta, let chars = event.charactersIgnoringModifiers, !chars.isEmpty {
            userInput("\u{1B}" + chars)
            return
        }
        interpretKeyEvents([event])
    }

    static func controlCode(_ scalar: Unicode.Scalar) -> UInt8? {
        switch scalar.value {
        case 0x61...0x7A: return UInt8(scalar.value - 0x60)
        case 0x40...0x5F: return UInt8(scalar.value - 0x40)
        case 0x20, 0x32: return 0
        case 0x33...0x37: return UInt8(scalar.value - 0x33 + 0x1B)
        case 0x38, 0x3F: return 0x7F
        case 0x2F, 0x2D: return 0x1F
        default: return nil
        }
    }

    private func specialSequence(_ event: NSEvent, _ mods: NSEvent.ModifierFlags) -> String? {
        let shift = mods.contains(.shift), option = mods.contains(.option), control = mods.contains(.control), command = mods.contains(.command)
        let modifier = 1 + (shift ? 1 : 0) + (option ? 2 : 0) + (control ? 4 : 0)
        func cursorKey(_ final: String) -> String {
            if modifier > 1 { return "\u{1B}[1;\(modifier)\(final)" }
            return (emulator.applicationCursorKeys ? "\u{1B}O" : "\u{1B}[") + final
        }
        func tilde(_ n: Int) -> String { modifier > 1 ? "\u{1B}[\(n);\(modifier)~" : "\u{1B}[\(n)~" }
        switch event.keyCode {
        case 126: return command ? nil : cursorKey("A")
        case 125: return command ? nil : cursorKey("B")
        case 124:
            if command { return "\u{05}" }
            if option && !shift && !control { return "\u{1B}f" }
            return cursorKey("C")
        case 123:
            if command { return "\u{01}" }
            if option && !shift && !control { return "\u{1B}b" }
            return cursorKey("D")
        case 115:
            if command || (!emulator.usingAlternateScreen && shift) { setScrollOffset(emulator.scrollback.count); return "" }
            return cursorKey("H")
        case 119:
            if command || (!emulator.usingAlternateScreen && shift) { setScrollOffset(0); return "" }
            return cursorKey("F")
        case 116:
            if !emulator.usingAlternateScreen || shift { setScrollOffset(scrollOffset + max(1, emulator.rows - 1)); return "" }
            return tilde(5)
        case 121:
            if !emulator.usingAlternateScreen || shift { setScrollOffset(scrollOffset - max(1, emulator.rows - 1)); return "" }
            return tilde(6)
        case 117: return tilde(3)
        case 51:
            if command { return "\u{15}" }
            return option ? "\u{1B}\u{7F}" : (control ? "\u{08}" : "\u{7F}")
        case 36, 76: return command ? nil : (option ? "\u{1B}\r" : "\r")
        case 48: return shift ? "\u{1B}[Z" : "\t"
        case 53: return "\u{1B}"
        case 122: return modifier > 1 ? "\u{1B}[1;\(modifier)P" : "\u{1B}OP"
        case 120: return modifier > 1 ? "\u{1B}[1;\(modifier)Q" : "\u{1B}OQ"
        case 99: return modifier > 1 ? "\u{1B}[1;\(modifier)R" : "\u{1B}OR"
        case 118: return modifier > 1 ? "\u{1B}[1;\(modifier)S" : "\u{1B}OS"
        case 96: return tilde(15)
        case 97: return tilde(17)
        case 98: return tilde(18)
        case 100: return tilde(19)
        case 101: return tilde(20)
        case 109: return tilde(21)
        case 103: return tilde(23)
        case 111: return tilde(24)
        default: return nil
        }
    }

    public func insertText(_ string: Any, replacementRange: NSRange) {
        markedText = ""
        let text = (string as? NSAttributedString)?.string ?? (string as? String) ?? ""
        userInput(text.replacingOccurrences(of: "\n", with: "\r"))
        needsDisplay = true
    }

    public override func doCommand(by selector: Selector) {}

    public func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        markedText = (string as? NSAttributedString)?.string ?? (string as? String) ?? ""
        needsDisplay = true
    }

    public func unmarkText() {
        markedText = ""
        needsDisplay = true
    }

    public func selectedRange() -> NSRange { NSRange(location: NSNotFound, length: 0) }
    public func markedRange() -> NSRange { markedText.isEmpty ? NSRange(location: NSNotFound, length: 0) : NSRange(location: 0, length: markedText.utf16.count) }
    public func hasMarkedText() -> Bool { !markedText.isEmpty }
    public func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? { nil }
    public func validAttributesForMarkedText() -> [NSAttributedString.Key] { [] }
    public func characterIndex(for point: NSPoint) -> Int { NSNotFound }

    public func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        guard let window else { return .zero }
        return window.convertToScreen(convert(cursorRect, to: nil))
    }

    public func paste(text: String) {
        var cleaned = text.replacingOccurrences(of: "\r\n", with: "\r").replacingOccurrences(of: "\n", with: "\r")
        if emulator.bracketedPaste {
            cleaned = cleaned.replacingOccurrences(of: "\u{1B}[201~", with: "")
            userInput("\u{1B}[200~" + cleaned + "\u{1B}[201~")
        } else {
            userInput(cleaned)
        }
    }

    @objc public func copy(_ sender: Any?) {
        guard let text = selectedText else { return NSSound.beep() }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    @objc public func paste(_ sender: Any?) {
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else { return NSSound.beep() }
        paste(text: text)
    }

    @objc public override func selectAll(_ sender: Any?) {
        selectionAnchor = stable(TerminalPosition(line: 0, column: 0))
        selectionHead = stable(TerminalPosition(line: emulator.totalLines - 1, column: emulator.columns - 1))
        selectionMode = 1
        needsDisplay = true
    }

    public func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(copy(_:)): return selectedText != nil
        case #selector(paste(_:)): return NSPasteboard.general.string(forType: .string) != nil
        default: return true
        }
    }

    private func position(at point: NSPoint, clamp: Bool = true) -> TerminalPosition {
        var column = Int(floor((point.x - Self.inset.width) / cellSize.width))
        var row = Int(floor((point.y - Self.inset.height) / cellSize.height))
        if clamp {
            column = min(max(0, column), emulator.columns - 1)
            row = min(max(0, row), emulator.rows - 1)
        }
        return TerminalPosition(line: topLine + row, column: column)
    }

    private var reportsMouse: Bool { emulator.mouseMode != .off }

    private func reportMouse(button: Int, at point: NSPoint, pressed: Bool, mods: NSEvent.ModifierFlags) {
        let p = position(at: point)
        let x = p.column + 1, y = p.line - topLine + 1
        var code = button
        if mods.contains(.shift) { code += 4 }
        if mods.contains(.option) { code += 8 }
        if mods.contains(.control) { code += 16 }
        if emulator.mouseSGR {
            send("\u{1B}[<\(code);\(x);\(y)\(pressed ? "M" : "m")")
        } else if x <= 223, y <= 223 {
            let b = pressed ? code : 3
            onInput?(Data([0x1B, 0x5B, 0x4D, UInt8(32 + b), UInt8(32 + x), UInt8(32 + y)]))
        }
    }

    public override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        let mods = event.modifierFlags
        if mods.contains(.command), openLink(at: position(at: point)) { return }
        if reportsMouse, !mods.contains(.option) {
            mouseReportedButton = 0
            reportMouse(button: 0, at: point, pressed: true, mods: [])
            return
        }
        let p = position(at: point)
        selectionMode = min(event.clickCount, 3)
        if mods.contains(.shift), selectionAnchor != nil {
            selectionHead = stable(p)
        } else if selectionMode == 1 {
            selectionAnchor = stable(p)
            selectionHead = nil
        } else {
            let (s, e) = expand(p, mode: selectionMode)
            selectionAnchor = stable(s)
            selectionHead = stable(e)
        }
        needsDisplay = true
    }

    public override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if mouseReportedButton != nil {
            if emulator.mouseMode == .drag || emulator.mouseMode == .motion { reportMouse(button: 32, at: point, pressed: true, mods: []) }
            return
        }
        guard let anchor = selectionAnchor else { return }
        if point.y < 0 { setScrollOffset(scrollOffset + 1) } else if point.y > bounds.height { setScrollOffset(scrollOffset - 1) }
        let p = position(at: point)
        if selectionMode == 1 {
            selectionHead = stable(p)
        } else {
            let a = expand(live(anchor), mode: selectionMode), h = expand(p, mode: selectionMode)
            selectionAnchor = stable(min(a.0, h.0))
            selectionHead = stable(max(a.1, h.1))
        }
        needsDisplay = true
    }

    public override func mouseUp(with event: NSEvent) {
        if mouseReportedButton != nil {
            mouseReportedButton = nil
            reportMouse(button: 0, at: convert(event.locationInWindow, from: nil), pressed: false, mods: [])
            return
        }
        if selectionHead == nil { selectionAnchor = nil }
        if settings.copyOnSelect, let text = selectedText {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
        needsDisplay = true
    }

    public override func otherMouseDown(with event: NSEvent) {
        if reportsMouse {
            reportMouse(button: 1, at: convert(event.locationInWindow, from: nil), pressed: true, mods: [])
        } else if event.buttonNumber == 2 {
            paste(nil)
        }
    }

    public override func otherMouseUp(with event: NSEvent) {
        if reportsMouse { reportMouse(button: 1, at: convert(event.locationInWindow, from: nil), pressed: false, mods: []) }
    }

    public override func scrollWheel(with event: NSEvent) {
        let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY / cellSize.height : event.scrollingDeltaY * 3
        wheelRemainder += delta
        let lines = Int(wheelRemainder.rounded(.towardZero))
        guard lines != 0 else { return }
        wheelRemainder -= CGFloat(lines)
        if reportsMouse {
            let point = convert(event.locationInWindow, from: nil)
            for _ in 0..<min(abs(lines), 10) { reportMouse(button: lines > 0 ? 64 : 65, at: point, pressed: true, mods: []) }
        } else if emulator.usingAlternateScreen {
            let key = (emulator.applicationCursorKeys ? "\u{1B}O" : "\u{1B}[") + (lines > 0 ? "A" : "B")
            send(String(repeating: key, count: min(abs(lines), 10)))
        } else {
            setScrollOffset(scrollOffset + lines)
        }
    }

    private static let wordBreaks = CharacterSet(charactersIn: " \t\"'`()[]{}<>|;,=")

    private func expand(_ p: TerminalPosition, mode: Int) -> (TerminalPosition, TerminalPosition) {
        let line = emulator.line(p.line)
        let last = max(0, line.cells.count - 1)
        if mode >= 3 { return (TerminalPosition(line: p.line, column: 0), TerminalPosition(line: p.line, column: last)) }
        func isBreak(_ x: Int) -> Bool {
            guard let scalar = line.cells[x].character.unicodeScalars.first else { return true }
            return Self.wordBreaks.contains(scalar)
        }
        let column = min(max(0, p.column), last)
        guard !isBreak(column) else { return (TerminalPosition(line: p.line, column: column), TerminalPosition(line: p.line, column: column)) }
        var start = column, end = column
        while start > 0, !isBreak(start - 1) { start -= 1 }
        while end < last, !isBreak(end + 1) { end += 1 }
        return (TerminalPosition(line: p.line, column: start), TerminalPosition(line: p.line, column: end))
    }

    public static func parseLink(_ token: String) -> (target: String, line: Int?) {
        var t = token
        while let last = t.last, ".,;:)".contains(last) { t.removeLast() }
        if t.contains("://") { return (t, nil) }
        let parts = t.split(separator: ":", omittingEmptySubsequences: false)
        if parts.count >= 2, let line = Int(parts[1]), !parts[0].isEmpty { return (String(parts[0]), line) }
        return (t, nil)
    }

    @discardableResult
    private func openLink(at p: TerminalPosition) -> Bool {
        let (s, e) = expand(p, mode: 2)
        let token = emulator.text(from: s, to: e)
        guard !token.isEmpty else { return false }
        let (target, line) = Self.parseLink(token)
        if let url = URL(string: target), let scheme = url.scheme?.lowercased(), ["http", "https", "file"].contains(scheme) {
            if url.isFileURL { return onOpenPath?(url.path, line) ?? false }
            NSWorkspace.shared.open(url)
            return true
        }
        var path = (target as NSString).expandingTildeInPath
        if !path.hasPrefix("/") {
            guard let base = currentDirectory?() else { return false }
            path = (base as NSString).appendingPathComponent(path)
        }
        path = (path as NSString).standardizingPath
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else { return false }
        if isDirectory.boolValue {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
            return true
        }
        return onOpenPath?(path, line) ?? false
    }

    public override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(withTitle: "Copy", action: #selector(copy(_:)), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Paste", action: #selector(paste(_:)), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Select All", action: #selector(selectAll(_:)), keyEquivalent: "").target = self
        let extra = contextMenuItems?() ?? []
        if !extra.isEmpty {
            menu.addItem(.separator())
            extra.forEach(menu.addItem)
        }
        return menu
    }

    public struct SearchResult: Equatable {
        public var current: Int
        public var total: Int
    }

    @discardableResult
    public func search(_ query: String, backwards: Bool = false, advance: Bool = true) -> SearchResult {
        if query != searchQuery || searchRevision != emulator.revision {
            let keepLine = searchIndex >= 0 && searchIndex < searchMatches.count ? searchMatches[searchIndex].line : nil
            searchQuery = query
            searchRevision = emulator.revision
            searchMatches = []
            if !query.isEmpty {
                for index in 0..<emulator.totalLines {
                    let line = emulator.line(index)
                    var text = ""
                    var columns: [Int] = []
                    for (x, cell) in line.cells.enumerated() where cell.width != 0 {
                        text.append(cell.character)
                        columns.append(x)
                    }
                    var from = text.startIndex
                    while let r = text.range(of: query, options: [.caseInsensitive], range: from..<text.endIndex) {
                        let a = text.distance(from: text.startIndex, to: r.lowerBound), b = text.distance(from: text.startIndex, to: r.upperBound)
                        if a < columns.count, b > a {
                            let endColumn = b - 1 < columns.count ? columns[b - 1] : emulator.columns - 1
                            searchMatches.append((index, columns[a], endColumn - columns[a] + 1))
                        }
                        from = r.upperBound
                    }
                }
            }
            if let keepLine, let i = searchMatches.firstIndex(where: { $0.line >= keepLine }) {
                searchIndex = i - (advance && !backwards ? 1 : 0)
            } else {
                searchIndex = backwards ? 0 : searchMatches.count
                if !advance { searchIndex = searchMatches.count - 1 }
            }
        }
        guard !searchMatches.isEmpty else {
            searchIndex = -1
            needsDisplay = true
            return SearchResult(current: 0, total: 0)
        }
        if advance {
            searchIndex = backwards ? searchIndex - 1 : searchIndex + 1
            if searchIndex < 0 { searchIndex = searchMatches.count - 1 }
            if searchIndex >= searchMatches.count { searchIndex = backwards ? searchMatches.count - 1 : 0 }
        }
        searchIndex = min(max(0, searchIndex), searchMatches.count - 1)
        reveal(line: searchMatches[searchIndex].line)
        needsDisplay = true
        return SearchResult(current: searchIndex + 1, total: searchMatches.count)
    }

    public func clearSearch() {
        searchQuery = ""
        searchMatches = []
        searchIndex = -1
        needsDisplay = true
    }

    private func reveal(line: Int) {
        let first = topLine
        if line >= first, line < first + emulator.rows { return }
        setScrollOffset(emulator.scrollback.count - line + emulator.rows / 2)
    }
}

private func == (a: (line: Int, column: Int, length: Int), b: (line: Int, column: Int, length: Int)) -> Bool {
    a.line == b.line && a.column == b.column && a.length == b.length
}
