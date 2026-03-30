import SwiftUI

struct TestToolsView: View {
    @EnvironmentObject private var projectManager: ProjectManager
    @StateObject private var testManager = TestToolsManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var selectedKinds = Set(TestKind.allCases)
    @State private var runParallel = true

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.08, green: 0.08, blue: 0.12).ignoresSafeArea()

                VStack(spacing: 12) {
                    controls
                    summaryRow
                    logPanel

                    List {
                        ForEach(filteredResults) { result in
                            TestResultRow(result: result)
                                .listRowBackground(Color.white.opacity(0.05))
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
                .padding(.top, 8)
            }
            .navigationTitle("Run Tests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            HStack {
                TextField("Search tests", text: $query)
                    .textFieldStyle(.roundedBorder)

                Toggle("Parallel", isOn: $runParallel)
                    .toggleStyle(.switch)
                    .labelsHidden()
                Text("Parallel")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                kindChip(.unit)
                kindChip(.integration)
                kindChip(.ui)

                Spacer()

                Button {
                    if let project = projectManager.activeProject {
                        Task { await testManager.runTests(forProject: project, kinds: selectedKinds, parallel: runParallel) }
                    }
                } label: {
                    Label("Run", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(testManager.isRunning)
            }
            .padding(.horizontal, 2)
        }
        .padding(.horizontal)
    }

    private var summaryRow: some View {
        HStack(spacing: 12) {
            summaryCard("Pass", value: "\(testManager.results.filter { $0.status == .success }.count)", color: .green)
            summaryCard("Fail", value: "\(testManager.results.filter { $0.status == .failed }.count)", color: .red)
            summaryCard("Warn", value: "\(testManager.results.filter { $0.status == .warning }.count)", color: .orange)
            summaryCard("Coverage", value: averageCoverageText, color: .blue)
        }
        .padding(.horizontal)
    }

    private var logPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Structured Logs")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            ScrollView {
                Text(testManager.structuredLogs.joined(separator: "\n").isEmpty ? "No logs yet." : testManager.structuredLogs.joined(separator: "\n"))
                    .font(.caption.monospaced())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 120)
        }
        .padding(10)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }

    private var filteredResults: [TestResult] {
        testManager.results.filter {
            (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || $0.suite.localizedCaseInsensitiveContains(query)) && selectedKinds.contains($0.kind)
        }
    }

    private var averageCoverageText: String {
        let values = testManager.results.flatMap { $0.fileCoverage.values }
        guard !values.isEmpty else { return "0%" }
        return "\(Int((values.reduce(0, +) / Double(values.count)) * 100))%"
    }

    private func kindChip(_ kind: TestKind) -> some View {
        Button(kind.rawValue.capitalized) {
            if selectedKinds.contains(kind) { selectedKinds.remove(kind) } else { selectedKinds.insert(kind) }
        }
        .buttonStyle(.bordered)
        .tint(selectedKinds.contains(kind) ? .blue : .gray)
    }

    private func summaryCard(_ title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline).foregroundStyle(color)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct TestResultRow: View {
    let result: TestResult

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: iconName(for: result.status))
                    .foregroundStyle(iconColor(for: result.status))
                Text("\(result.suite) • \(result.name)")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(Int(result.executionTime * 1000)) ms")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Type: \(result.kind.rawValue.capitalized)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let error = result.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if !result.stackTrace.isEmpty {
                Text(result.stackTrace.joined(separator: " → "))
                    .font(.caption2.monospaced())
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
    }

    private func iconName(for status: TestStatus) -> String {
        switch status { case .success: return "checkmark.circle.fill"; case .warning: return "exclamationmark.triangle.fill"; case .failed: return "xmark.circle.fill" }
    }

    private func iconColor(for status: TestStatus) -> Color {
        switch status { case .success: return .green; case .warning: return .orange; case .failed: return .red }
    }
}
