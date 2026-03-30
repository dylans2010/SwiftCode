import SwiftUI

struct TestToolsView: View {
    @EnvironmentObject private var projectManager: ProjectManager
    @StateObject private var testManager = TestToolsManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: TestTab = .dashboard
    @State private var searchText = ""

    enum TestTab: String, CaseIterable {
        case dashboard = "Dashboard"
        case results = "Last Run"
        case history = "History"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Tab", selection: $selectedTab) {
                    ForEach(TestTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                switch selectedTab {
                case .dashboard:
                    dashboardView
                case .results:
                    resultsView
                case .history:
                    historyView
                }
            }
            .background(Color(red: 0.05, green: 0.05, blue: 0.07).ignoresSafeArea())
            .navigationTitle("Test Suite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }

                ToolbarItem(placement: .topBarLeading) {
                    if testManager.isRunning {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
        }
    }

    private var dashboardView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Summary Section
                HStack(spacing: 16) {
                    VStack(alignment: .leading) {
                        Text("\(Int(testManager.codeCoverage))%")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.green)
                        Text("Code Coverage")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading) {
                        Text("\(testManager.testHistory.first?.passRate ?? 0, format: .percent)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.blue)
                        Text("Last Pass Rate")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                }

                // Actions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Actions")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Button {
                        if let project = projectManager.activeProject {
                            Task {
                                await testManager.runTests(forProject: project)
                                selectedTab = .results
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Run Full Test Suite")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .padding()
                        .background(Color.orange, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white)
                    }
                    .disabled(testManager.isRunning)

                    HStack(spacing: 12) {
                        categoryButton(title: "Unit", icon: "cube.fill", category: .unit)
                        categoryButton(title: "Integration", icon: "arrow.3.trianglepath", category: .integration)
                        categoryButton(title: "UI", icon: "iphone", category: .ui)
                    }
                }

                // Recent History Mini-chart
                if !testManager.testHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Pass Rate History")
                            .font(.headline)

                        HStack(alignment: .bottom, spacing: 4) {
                            ForEach(testManager.testHistory.prefix(10).reversed()) { entry in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(entry.failedTests > 0 ? Color.red : Color.green)
                                    .frame(width: 20, height: CGFloat(entry.passRate * 100))
                            }
                        }
                        .frame(height: 100)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding()
        }
    }

    private func categoryButton(title: String, icon: String, category: TestCategory) -> some View {
        Button {
            if let project = projectManager.activeProject {
                Task {
                    await testManager.runTests(forProject: project, category: category)
                    selectedTab = .results
                }
            }
        } label: {
            VStack {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.blue.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
            .foregroundStyle(.blue)
        }
        .disabled(testManager.isRunning)
    }

    private var resultsView: some View {
        VStack(spacing: 0) {
            if testManager.results.isEmpty {
                ContentUnavailableView("No Results", systemImage: "testtube.2", description: Text("Run tests from the dashboard to see results here."))
            } else {
                List {
                    ForEach(TestCategory.allCases) { cat in
                        let catResults = testManager.results.filter { $0.category == cat }
                        if !catResults.isEmpty {
                            Section(cat.rawValue) {
                                ForEach(catResults) { result in
                                    TestResultRow(result: result)
                                }
                            }
                            .listRowBackground(Color.white.opacity(0.05))
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
    }

    private var historyView: some View {
        List {
            ForEach(testManager.testHistory) { entry in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline.bold())
                        Text("\(entry.passedTests) passed, \(entry.failedTests) failed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("\(Int(entry.passRate * 100))%")
                            .font(.headline)
                            .foregroundStyle(entry.failedTests == 0 ? .green : .orange)
                        Text(String(format: "%.1fs", entry.duration))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(Color.white.opacity(0.05))
            }
        }
        .scrollContentBackground(.hidden)
    }
}

struct TestResultRow: View {
    let result: TestResult

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: iconName(for: result.status))
                    .foregroundStyle(iconColor(for: result.status))

                Text(result.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)

                Spacer()

                Text(String(format: "%.2f ms", result.executionTime * 1000))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let error = result.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.leading, 24)
            }
        }
        .padding(.vertical, 4)
    }

    private func iconName(for status: TestStatus) -> String {
        switch status {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .failed:  return "xmark.circle.fill"
        }
    }

    private func iconColor(for status: TestStatus) -> Color {
        switch status {
        case .success: return .green
        case .warning: return .orange
        case .failed:  return .red
        }
    }
}
