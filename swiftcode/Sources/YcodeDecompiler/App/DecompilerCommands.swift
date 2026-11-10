import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Command identifiers for the Decompiler workspace. Only implemented
/// commands are registered — there are no stub entries.
public enum DecompilerCommands {
    public enum Command: String, CaseIterable, Sendable {
        /// NSOpenPanel → import a binary into the session.
        case openBinary
        /// NSOpenPanel → open a `.scdecomp` project.
        case openProject
        /// Save the session's analysis into its `.scdecomp` project
        /// (or prompt for a new project location when none exists).
        case saveProject
        /// Run the static analysis pipeline.
        case analyze
        /// Cancel the running analysis.
        case cancelAnalysis
        /// Toggle Friendly ↔ Master workspace mode.
        case switchMode
        /// Toggle the Decompile Assist panel.
        case showAssist
        /// Toggle the inspector.
        case toggleInspector
        /// Toggle the analysis console.
        case toggleConsole
        /// Ask the focused browser to show its search field.
        case search
        /// Ask the focused editor to show its go-to-address field.
        case goToAddress
        /// Ask the workspace to jump to a function by name.
        case goToFunction
        /// Write a text report (pseudocode, disassembly, strings, symbols)
        /// to a user-chosen file.
        case exportAnalysis
        /// Reset pane visibility and selection to defaults.
        case restoreLayout
    }

    /// Perform a command against a specific workspace state.
    @MainActor
    public static func perform(_ command: Command, on state: DecompilerObservableState) {
        switch command {
        case .openBinary:
            guard let url = presentOpenPanel(
                allowedTypes: ["mach-o", "elf", "bin", "o", "a", "dylib", "so", "exe", "dll"]) else { return }
            Task {
                do { _ = try await state.importBinary(at: url) }
                catch { state.log("Import failed: \(error.localizedDescription)", kind: .error) }
            }

        case .openProject:
            guard let url = presentOpenPanel(allowedTypes: ["scdecomp"], chooseDirectories: true) else { return }
            Task {
                do {
                    let session = try await DecompilerSessionManager.shared.openProject(at: url)
                    // openProject attaches the manifest to the new session;
                    // show its own window.
                    await DecompilerWindowManager.shared.showWindowAsync(sessionID: session.id)
                } catch {
                    state.log("Open project failed: \(error.localizedDescription)", kind: .error)
                }
            }

        case .saveProject:
            Task {
                if await state.session.project != nil {
                    do { _ = try await state.saveProject() }
                    catch { state.log("Save failed: \(error.localizedDescription)", kind: .error) }
                } else {
                    // No project yet: ask where to create the .scdecomp bundle.
                    let panel = NSSavePanel()
                    panel.nameFieldStringValue = "Analysis.scdecomp"
                    panel.canCreateDirectories = true
                    panel.isExtensionHidden = false
                    panel.allowedContentTypes = [UTType(filenameExtension: "scdecomp") ?? .folder]
                    if panel.runModal() == .OK, let url = panel.url {
                        do { _ = try await state.saveProject(to: url) }
                        catch { state.log("Save failed: \(error.localizedDescription)", kind: .error) }
                    }
                }
            }

        case .analyze:
            state.startAnalysis()

        case .cancelAnalysis:
            state.cancelAnalysis()

        case .switchMode:
            Task { await state.toggleMode() }

        case .showAssist:
            state.showAssist.toggle()

        case .toggleInspector:
            state.showInspector.toggle()

        case .toggleConsole:
            state.showConsole.toggle()

        case .search:
            state.pendingCommand = .search

        case .goToAddress:
            promptForAddress(state)

        case .goToFunction:
            promptForFunction(state)

        case .exportAnalysis:
            exportAnalysis(state)

        case .restoreLayout:
            state.showInspector = true
            state.showConsole = false
            state.showAssist = true
            state.selectedFunctionAddress = nil
            state.selectedAddress = nil
            state.selectedInstructionRange = nil
            state.inspectorItem = .none
        }
    }

    /// Perform a command against the frontmost Decompiler window.
    @MainActor
    public static func perform(_ command: Command) {
        guard let state = DecompilerWindowManager.shared.activeState else { return }
        perform(command, on: state)
    }

    // MARK: - Panels

    @MainActor
    @discardableResult
    private static func presentOpenPanel(allowedTypes: [String],
                                         chooseDirectories: Bool = false) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = !chooseDirectories
        panel.canChooseDirectories = chooseDirectories
        panel.allowsMultipleSelection = false
        let types = allowedTypes.compactMap { UTType(filenameExtension: $0) }
        // `.data` keeps extensionless binaries selectable; specific types
        // still rank first in the dialog.
        panel.allowedContentTypes = types.isEmpty ? [.data, .executable, .archive] : types + [.data]
        return panel.runModal() == .OK ? panel.url : nil
    }

    // MARK: - Go-to prompts

    /// Modal prompt for a virtual address; navigates and selects on success.
    @MainActor
    private static func promptForAddress(_ state: DecompilerObservableState) {
        let alert = NSAlert()
        alert.messageText = "Go to Address"
        alert.informativeText = "Enter a virtual address (0x…)."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        field.placeholderString = "0x…"
        alert.accessoryView = field
        alert.addButton(withTitle: "Go")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn,
           let addr = DecompilerAddress.parse(field.stringValue) {
            state.navigate(to: addr)
            state.selectAddress(addr, inspector: .address)
        }
    }

    /// Modal prompt for a function name; selects the first case-insensitive
    /// match and reports misses through the console log.
    @MainActor
    private static func promptForFunction(_ state: DecompilerObservableState) {
        let alert = NSAlert()
        alert.messageText = "Go to Function"
        alert.informativeText = "Enter a function name or address."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        alert.accessoryView = field
        alert.addButton(withTitle: "Go")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() != .alertFirstButtonReturn { return }
        let query = field.stringValue.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }

        // Address input?
        if let addr = DecompilerAddress.parse(query),
           let fn = state.function(containing: addr) {
            state.selectFunction(fn)
            return
        }
        let q = query.lowercased()
        if let fn = state.functions.first(where: {
            $0.displayName.lowercased() == q || $0.name.lowercased() == q
        }) ?? state.functions.first(where: {
            $0.displayName.lowercased().contains(q) || $0.name.lowercased().contains(q)
        }) {
            state.selectFunction(fn)
        } else {
            state.log("No function matching '\(query)'", kind: .warning)
        }
    }

    // MARK: - Export

    /// Write a real text report: header, overview, function list, all
    /// generated pseudocode, the selected function's disassembly, strings,
    /// symbols and history. No placeholder content — sections are included
    /// only when the session actually has that data.
    @MainActor
    private static func exportAnalysis(_ state: DecompilerObservableState) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "analysis-report.txt"
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        Task {
            var out = ""
            out += "SwiftCode Decompiler — Analysis Export\n"
            out += "Generated: \(Date())\n\n"

            if let image = state.binary {
                out += "== Binary ==\n"
                out += "Name:        \(image.identity.originalFileName)\n"
                out += "Format:      \(image.format.displayName)\n"
                out += "Architecture:\(image.architecture.displayName)\n"
                out += "CPU:         \(image.cpuIdentifier)\n"
                out += "File size:   \(image.identity.fileSize) bytes\n"
                out += "Entry point: \(image.entryPoint?.hexString ?? "n/a")\n"
                out += "SHA-256:     \(image.identity.sha256)\n"
                out += "Signed:      \(image.isSigned)\n"
                out += "Encrypted:   \(image.isEncrypted)\n"
                out += "Debug info:  \(image.hasDebugInfo)\n\n"
            }

            let counts = state.overviewCounts
            out += "== Overview ==\n"
            out += "Functions: \(counts.functions)\nSymbols: \(counts.symbols)\n"
            out += "Imports: \(counts.imports)\nExports: \(counts.exports)\n"
            out += "Strings: \(counts.strings)\nSections: \(counts.sections)\n\n"

            if !state.functions.isEmpty {
                out += "== Functions ==\n"
                for fn in state.functions {
                    out += "\(fn.address.hexString)  \(fn.size) B  \(fn.kind.rawValue)  \(fn.displayName)\n"
                }
                out += "\n"
            }

            // Pseudocode for every decompiled function.
            if !state.pseudocode.isEmpty {
                out += "== Pseudocode ==\n\n"
                for (addr, result) in state.pseudocode.sorted(by: { $0.key < $1.key }) {
                    out += "// \(result.functionName) @ 0x\(String(addr, radix: 16))\n"
                    out += result.pseudocode
                    out += "\n\n"
                }
            }

            // Disassembly of the selected function, if loaded.
            if !state.disassembly.isEmpty {
                out += "== Disassembly (\(state.disassemblyFunctionAddress?.hexString ?? "")) ==\n\n"
                for ins in state.disassembly {
                    let bytes = ins.rawBytes.map { String(format: "%02x", $0) }.joined(separator: " ")
                    out += "\(ins.address.hexString)  \(bytes.padding(toLength: 24, withPad: " ", startingAt: 0))  \(ins.text)\n"
                }
                out += "\n"
            }

            if !state.strings.isEmpty {
                out += "== Strings ==\n"
                for s in state.strings {
                    out += "\(s.address.hexString)  \(s.text)\n"
                }
                out += "\n"
            }

            if !state.symbols.isEmpty {
                out += "== Symbols ==\n"
                for sym in state.symbols {
                    out += "\(sym.address?.hexString ?? "-")  \(sym.kind.rawValue)  \(sym.effectiveName)\n"
                }
                out += "\n"
            }

            if !state.history.isEmpty {
                out += "== Analysis History ==\n"
                for entry in state.history {
                    out += "\(entry.date.ISO8601Format())  \(entry.operation)  \(entry.detail)\n"
                }
            }

            do {
                try out.write(to: url, atomically: true, encoding: .utf8)
                await MainActor.run {
                    state.log("Exported analysis report to \(url.lastPathComponent)", kind: .engine)
                }
            } catch {
                await MainActor.run {
                    state.log("Export failed: \(error.localizedDescription)", kind: .error)
                }
            }
        }
    }
}

private extension String {
    func padding(toLength: Int, withPad pad: Character, startingAt: Int) -> String {
        count >= toLength ? self : self + String(repeating: pad, count: toLength - count)
    }
}
