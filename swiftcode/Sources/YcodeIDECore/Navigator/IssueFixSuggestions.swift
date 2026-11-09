import Foundation
import YcodeBuild

public enum IssueFixSuggestions {

    public static func suggestions(for d: Diagnostic) -> [String] {
        var out: [String] = []
        func add(_ s: String) { if !out.contains(s) { out.append(s) } }

        for f in d.fixIts {
            let file = URL(fileURLWithPath: f.file).lastPathComponent
            var s = "Apply the compiler-suggested fix-it in \(file) (lines \(f.start.line)–\(f.end.line))."
            let preview = f.replacement
                .replacingOccurrences(of: "\n", with: "\\n")
            let clipped = preview.count > 80 ? String(preview.prefix(80)) + "…" : preview
            if !clipped.isEmpty { s += " It replaces that range with “\(clipped)”." }
            add(s)
        }

        let m = d.message
        let l = m.lowercased()
        let loc = locationText(d)

        if l.contains("cannot find") && (l.contains("in scope") || l.contains("unresolved identifier")) {
            add("Declare the symbol or fix a typo — Swift names are case-sensitive, so check the spelling at the declaration site.")
            add("If the symbol lives in another module or file, add the missing `import` or make sure that file belongs to the same target.")
            add("If it is a member, qualify it (`Type.member` or `instance.member`); if it is a global, confirm the declaring file is compiled into this target.")
        }
        if l.contains("has no member") || (l.contains("value of type") && l.contains("has no member")) {
            add("Check the member name for typos and confirm the receiver's type — the compiler reports the actual type in the message.")
            add("If the value is optional, unwrap it first (`guard let`/`if let`) or use optional chaining (`?.`).")
            add("If the member comes from a protocol or extension, verify the conformance/extension is visible to this file.")
        }
        if l.contains("cannot convert") || l.contains("type mismatch") || (l.contains("cannot be used") && l.contains("type")) {
            add("Make the types agree: add an explicit type annotation, convert with the right initializer, or correct the generic arguments.")
            add("For string/number bridging, pick the literal type explicitly (e.g. `\"…\" as String` vs `Substring`) or use `String(describing:)`.")
        }
        if l.contains("ambiguous") {
            add("Disambiguate by adding an explicit type annotation or qualifying the member with its type name.")
        }
        if l.contains("missing argument") || l.contains("extra argument") || (l.contains("argument") && l.contains("expects")) {
            add("Match the call to the declaration: supply the missing arguments, remove the extra ones, or fix the argument labels/order.")
        }
        if l.contains("does not conform") || l.contains("protocol requirement") {
            add("Implement the missing protocol requirements, or remove the conformance if it is no longer needed.")
            add("Check for `required` initializers and that associated types can be inferred from the concrete members.")
        }
        if l.contains("no such module") || l.contains("missing required module") || l.contains("file not found") {
            add("Add the package/product dependency to the target's build settings, or fix the `import` spelling.")
            add("Verify the module is built for the active destination and that its target membership includes this file.")
        }
        if l.contains("deprecated") {
            if let range = m.range(of: "renamed to '") ?? m.range(of: "renamed to \"") {
                let rest = m[range.upperBound...]
                let end = rest.firstIndex(where: { $0 == "'" || $0 == "\"" }) ?? rest.endIndex
                add("Replace the deprecated API with its replacement: `\(rest[..<end])`.")
            } else {
                add("Replace the deprecated API with its modern equivalent; check the documentation or the compiler note for the suggested replacement.")
            }
        }
        if l.contains("unexpectedly found nil") || l.contains("force-unwrap") || l.contains("force unwrap") {
            add("Replace the force unwrap with `guard let`/`if let` and handle the nil case explicitly.")
            add("Alternatively use optional chaining (`?.`) if a nil result is acceptable downstream.")
        }
        if l.contains("main actor") || l.contains("actor-isolated") || l.contains("is not async") || l.contains("call is 'async'") {
            add("Add `await` at the call site, mark the caller `async`, or isolate the code with `@MainActor`/`nonisolated` as appropriate.")
        }
        if l.contains("simultaneous accesses") || l.contains("exclusivity") {
            add("Restructure so the conflicting accesses do not overlap: copy the value to a local, split the call, or reorder the statements.")
        }
        if l.contains("unreachable code") {
            add("Remove the unreachable statements, or fix the preceding condition so the code can execute.")
        }
        if l.contains("never used") || l.contains("unused") {
            add("Remove the unused declaration, or prefix it with `_` if it must remain for API or debugging reasons.")
        }
        if l.contains("expected") && (l.contains("separator") || l.contains("expression") || l.contains("'}'") || l.contains("')'")) {
            add("Check brackets, commas and quotes around the reported line — the parser hit something unexpected before this point.")
        }
        if l.contains("cannot assign") && (l.contains("let") || l.contains("immutable")) {
            add("Change `let` to `var`, or assign through a mutable copy or property instead of the constant.")
        }
        if l.contains("circular") || l.contains("retain cycle") {
            add("Break the cycle with a weak/unowned reference or restructure ownership so the objects do not retain each other.")
        }
        if l.contains("overflow") || l.contains("out of range") {
            add("Check the literal or computed value against the type's range; use a wider type or clamp the value.")
        }

        if !d.notes.isEmpty {
            add("Read the \(d.notes.count) compiler note\(d.notes.count == 1 ? "" : "s") attached to this diagnostic — they usually point at the exact conflicting declaration.")
        }
        if let loc {
            add("Open \(loc) and fix the reported construct; the gutter and the Issue Navigator both jump to it on a single click.")
        } else {
            add("This diagnostic has no source location — check the build log around it for the failing file or command.")
        }
        add("If the cause is not obvious, use the Fix Issues button to send all current errors to Assist.")
        return out
    }

    private static func locationText(_ d: Diagnostic) -> String? {
        guard let l = d.location else { return nil }
        let file = URL(fileURLWithPath: l.file).lastPathComponent
        if l.column > 0 { return "\(file):\(l.line):\(l.column)" }
        return l.line > 0 ? "\(file):\(l.line)" : file
    }
}

public enum BuildIssuesReport {
    public static let fileName = "BuildFailed.txt"

    public static func fileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftCode", isDirectory: true)
            .appendingPathComponent(fileName)
    }

    public static func write(_ diagnostics: [Diagnostic]) throws -> URL {
        var text = "Build Issues\n============\n"
        text += "Generated: \(ISO8601DateFormatter().string(from: Date()))\n"
        text += "Diagnostics: \(diagnostics.count)\n\n"
        for (i, d) in diagnostics.enumerated() {
            text += "[\(i + 1)] \(d.severity.rawValue): \(d.message)\n"
            if let l = d.location {
                text += "    at: \(l.file):\(l.line)"
                if l.column > 0 { text += ":\(l.column)" }
                text += "\n"
            }
            for n in d.notes {
                text += "    note: \(n.message)"
                if let nl = n.location { text += " (\(nl.file):\(nl.line))" }
                text += "\n"
            }
            for f in d.fixIts {
                let preview = f.replacement.replacingOccurrences(of: "\n", with: "\\n")
                let clipped = preview.count > 200 ? String(preview.prefix(200)) + "…" : preview
                text += "    fix-it: \(f.file):\(f.start.line):\(f.start.column)-\(f.end.line):\(f.end.column) -> \"\(clipped)\"\n"
            }
            text += "\n"
        }
        let url = fileURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
