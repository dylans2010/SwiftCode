import SwiftUI
import AppKit

public struct AssemblyResultView: View {
    @Bindable var state: DecompilerObservableState

    public init(state: DecompilerObservableState) {
        self.state = state
    }

    public var body: some View {
        if let result = state.lastAssembly {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header(result: result)
                    outputSection(result: result)
                    backendSection(result: result)
                    equivalenceSection(result: result)
                    diagnosticsSection(result: result)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            EmptyStateView(
                systemImage: "hammer",
                title: "No Assemble run yet",
                message: "Run Assemble to compile the reconstructed project into a new dynamic library. The output path, equivalence verdict, and diagnostics will appear here."
            )
        }
    }

    private func header(result: AssemblyResult) -> some View {
        HStack(spacing: 8) {
            Image(systemName: result.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(result.succeeded ? .green : .red)
            Text(result.succeeded ? "Assemble succeeded" : "Assemble failed")
                .font(.headline)
            Spacer()
            Text("\(result.filesCompiled.count) compiled, \(result.filesReused.count) reused")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(String(format: "%.2fs", result.duration))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func outputSection(result: AssemblyResult) -> some View {
        ExplainedSection("Output", explanation: "The dynamic library Assemble produced. Reveal in Finder opens the folder containing it; the build report records the same run in text form.") {
            InfoRow("Output", result.outputURL.path, mono: true)
            HStack(spacing: 8) {
                if FileManager.default.fileExists(atPath: result.outputURL.path) {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([result.outputURL])
                    } label: {
                        Label("Reveal in Finder", systemImage: "folder")
                    }
                    .controlSize(.small)
                }
                CopyButton(result.outputURL.path)
                if let reportURL = result.reportURL {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([reportURL])
                    } label: {
                        Label("Reveal Build Report", systemImage: "doc.text")
                    }
                    .controlSize(.small)
                }
            }
        }
    }

    private func backendSection(result: AssemblyResult) -> some View {
        ExplainedSection("Backend", explanation: "Which Assemble backend built this library and the build settings it used. Automatic means each source file was routed to the backend registered for its extension.") {
            InfoRow("Backend", selectedBackendName)
            if !result.compilerPath.isEmpty {
                InfoRow("Compiler", result.compilerPath, mono: true)
            }
            if let configuration = state.reconstructedProject?.configuration {
                InfoRow("Architectures", configuration.architectures.map(\.displayName).joined(separator: ", "))
                if let deploymentTarget = configuration.deploymentTarget {
                    InfoRow("Deployment target", deploymentTarget)
                }
                if let installName = configuration.installName {
                    InfoRow("Install name", installName, mono: true)
                }
                InfoRow("Optimization", "O\(configuration.optimizationLevel)")
                if !configuration.frameworks.isEmpty {
                    InfoRow("Frameworks", configuration.frameworks.joined(separator: ", "))
                }
            }
        }
    }

    private var selectedBackendName: String {
        guard let id = state.selectedBackendID else {
            return "Automatic (per file extension)"
        }
        if let backend = BackendRegistry.backend(id: id) {
            return backend.displayName
        }
        return id
    }

    private func equivalenceSection(result: AssemblyResult) -> some View {
        ExplainedSection("Equivalence vs original", explanation: "Structural comparison of the rebuilt library against the original: format, architecture, install name, and export/import/dependency name sets. A matching verdict means the library builds and its exports match — it does not prove the code behaves the same.") {
            if let equivalence = result.equivalence {
                InfoRow("Verdict", verdictText(equivalence.verdict))
                InfoRow("Format matches", equivalence.formatMatches ? "Yes" : "No")
                InfoRow("Architecture matches", equivalence.architectureMatches ? "Yes" : "No")
                InfoRow("Install name matches", equivalence.installNameMatches ? "Yes" : "No")
                InfoRow("ABI compatible", equivalence.isABICompatible ? "Yes — no missing exports" : "No — exports are missing")
                if !equivalence.missingExports.isEmpty {
                    InfoRow("Missing exports", equivalence.missingExports.map(\.name).joined(separator: ", "), mono: true)
                }
                if !equivalence.addedExports.isEmpty {
                    InfoRow("Added exports", equivalence.addedExports.map(\.name).joined(separator: ", "), mono: true)
                }
                if !equivalence.notes.isEmpty {
                    ForEach(equivalence.notes, id: \.self) { note in
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(equivalence.behavioralEquivalence)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No equivalence comparison was produced for this run.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func verdictText(_ verdict: EquivalenceReport.Verdict) -> String {
        switch verdict {
        case .compatible: return "Compatible"
        case .compatibleWithDifferences: return "Compatible with differences"
        case .incompatible: return "Incompatible"
        case .unknown: return "Unknown"
        }
    }

    private func diagnosticsSection(result: AssemblyResult) -> some View {
        ExplainedSection("Diagnostics", explanation: "Compiler, linker, and configuration diagnostics from the Assemble run, with fix suggestions where the parser could derive one.") {
            if result.diagnostics.isEmpty {
                Text("No diagnostics.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(result.diagnostics.enumerated()), id: \.offset) { _, diagnostic in
                    diagnosticRow(diagnostic)
                }
            }
        }
    }

    private func diagnosticRow(_ diagnostic: AssemblyDiagnostic) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: severityIcon(diagnostic.severity))
                    .foregroundStyle(severityColor(diagnostic.severity))
                Text(diagnostic.displayLocation.isEmpty ? diagnostic.message : "\(diagnostic.displayLocation) \(diagnostic.message)")
                    .font(.callout)
                    .textSelection(.enabled)
            }
            if let suggestion = diagnostic.suggestion {
                Text(suggestion)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func severityIcon(_ severity: AssemblyDiagnostic.Severity) -> String {
        switch severity {
        case .error: return "xmark.octagon.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .note: return "note.text"
        case .info: return "info.circle"
        }
    }

    private func severityColor(_ severity: AssemblyDiagnostic.Severity) -> Color {
        switch severity {
        case .error: return .red
        case .warning: return .orange
        case .note: return .secondary
        case .info: return .secondary
        }
    }
}
