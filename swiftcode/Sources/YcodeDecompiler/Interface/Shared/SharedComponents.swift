import SwiftUI
import AppKit

/// Plain-language explanations of decompiler terminology, shown in info rows
/// and tooltips throughout Friendly and Master modes.
public enum Explainer {
    public static let function = "A function is a named block of code that performs one job. The decompiler recovers these from the symbol table and by spotting function prologues in the machine code."
    public static let symbol = "A symbol is a named address inside the binary — usually a function, global variable, or constant — recovered from the symbol table. Symbols give names to otherwise anonymous addresses."
    public static let importSymbol = "An imported symbol is a function or value this binary uses but does not contain — it is provided by another library at runtime (for example a system framework)."
    public static let exportSymbol = "An exported symbol is a function or value this binary offers to other programs that link against it."
    public static let string = "A string is a run of human-readable text embedded in the binary — UI labels, format strings, error messages, file paths."
    public static let section = "A section is a named region of the file with a fixed purpose, like __text (code) or __cstring (strings). Sections live inside larger segments."
    public static let segment = "A segment is a large memory region loaded as a unit, with uniform access permissions (read/write/execute). The Mach-O __TEXT segment holds code."
    public static let pseudocode = "Pseudocode is the decompiler's best-effort C-like reconstruction of what a function does. It is an approximation for understanding — it will not compile and may contain errors."
    public static let disassembly = "Disassembly is the direct translation of machine-code bytes into assembly instructions, one instruction at a time."
    public static let crossReference = "A cross-reference (xref) records that one address refers to another — a call, jump, or data pointer. Xrefs reveal how code is connected."
    public static let address = "Addresses are shown in hexadecimal (0x…). Virtual addresses are where code sits in memory after loading; file offsets are positions in the file on disk."
    public static let basicBlock = "A basic block is a straight-line run of instructions with a single entry and a single exit — the unit used to draw the control-flow graph."
    public static let entitlements = "Entitlements are permissions embedded in the code signature declaring what the binary is allowed to do (keychain access, sandbox exceptions, and so on)."
    public static let debugInfo = "Debug information (DWARF or PDB) preserves original variable names, types, and source line numbers. Its absence makes decompiled output harder to read."
    public static let provenance = "Provenance records where a piece of analysis came from: the file format itself, the symbol table, an analysis engine, a heuristic, or a user edit. AI suggestions are never treated as verified facts."
}

/// Text field that accepts `0x…` (or plain hex/decimal) addresses and
/// navigates on submit. Used by both workspaces.
public struct AddressField: View {
    let placeholder: String
    let onNavigate: (DecompilerAddress) -> Void
    @State private var text = ""
    @State private var invalid = false

    public init(placeholder: String = "0x…", onNavigate: @escaping (DecompilerAddress) -> Void) {
        self.placeholder = placeholder
        self.onNavigate = onNavigate
    }

    public var body: some View {
        HStack(spacing: 4) {
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .frame(minWidth: 110, maxWidth: 180)
                .onSubmit(submit)
            if invalid {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .help("Not a valid address")
            }
        }
    }

    private func submit() {
        if let addr = DecompilerAddress.parse(text) {
            invalid = false
            onNavigate(addr)
        } else {
            invalid = true
        }
    }
}

/// Reusable search field with clear button.
public struct SearchBar: View {
    @Binding var text: String
    let placeholder: String

    public init(text: Binding<String>, placeholder: String = "Search") {
        self._text = text
        self.placeholder = placeholder
    }

    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}

/// Bottom status bar: analysis stage, real fraction when known, message.
public struct StatusBar: View {
    let progress: AnalysisProgress
    let isAnalyzing: Bool
    var extra: String? = nil

    public init(progress: AnalysisProgress, isAnalyzing: Bool, extra: String? = nil) {
        self.progress = progress
        self.isAnalyzing = isAnalyzing
        self.extra = extra
    }

    public var body: some View {
        HStack(spacing: 10) {
            if isAnalyzing {
                ProgressView()
                    .controlSize(.small)
            }
            Text(stageLabel)
                .font(.callout.weight(.medium))
            if let fraction = progress.fraction {
                ProgressView(value: fraction)
                    .frame(width: 140)
                Text("\(Int(fraction * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else if progress.stage != .idle {
                ProgressView()
                    .controlSize(.small)
            }
            if !progress.message.isEmpty {
                Text(progress.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            if let extra { Text(extra).font(.caption).foregroundStyle(.secondary) }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.bar)
    }

    private var stageLabel: String {
        switch progress.stage {
        case .idle: return isAnalyzing ? "Working…" : "Ready"
        case .importing: return "Importing"
        case .parsing: return "Parsing"
        case .detectingArchitecture: return "Detecting architecture"
        case .discoveringFunctions: return "Discovering functions"
        case .buildingSymbols: return "Building symbols"
        case .disassembling: return "Disassembling"
        case .decompiling: return "Decompiling"
        case .buildingReferences: return "Building references"
        case .extractingStrings: return "Extracting strings"
        case .persisting: return "Saving"
        case .completed: return "Analysis complete"
        case .failed: return "Analysis failed"
        case .cancelled: return "Analysis cancelled"
        }
    }
}

/// Centered empty-state placeholder with symbol, title and explanation.
public struct EmptyStateView: View {
    let systemImage: String
    let title: String
    var message: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    public init(systemImage: String, title: String, message: String? = nil,
                actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.title3.weight(.semibold))
            if let message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }
}

/// Right-side inspector container: titled section with a content closure.
public struct InspectorPanel<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var content: () -> Content

    public init(_ title: String, subtitle: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    if let subtitle {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Divider()
                content()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// A labelled info row used across inspector/detail views.
public struct InfoRow: View {
    let label: String
    let value: String
    var mono = false
    var help: String? = nil

    public init(_ label: String, _ value: String, mono: Bool = false, help: String? = nil) {
        self.label = label
        self.value = value
        self.mono = mono
        self.help = help
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .font(mono ? .system(.callout, design: .monospaced) : .callout)
                .textSelection(.enabled)
                .help(help ?? value)
            Spacer(minLength: 0)
        }
    }
}

/// Section header with an info button carrying a plain-language explanation.
public struct ExplainedSection<Content: View>: View {
    let title: String
    var explanation: String? = nil
    @ViewBuilder var content: () -> Content

    public init(_ title: String, explanation: String? = nil,
                @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.explanation = explanation
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(title).font(.headline)
                if let explanation {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                        .help(explanation)
                }
            }
            content()
        }
    }
}

/// Copy-to-pasteboard button.
public struct CopyButton: View {
    let text: String
    var label: String = "Copy"

    public init(_ text: String, label: String = "Copy") {
        self.text = text
        self.label = label
    }

    public var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        } label: {
            Label(label, systemImage: "doc.on.doc")
        }
        .controlSize(.small)
    }
}
