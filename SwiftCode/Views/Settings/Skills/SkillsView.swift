import SwiftUI

struct SkillsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = AgentSkillManager.shared
    @State private var showAddView = false

    var body: some View {
        NavigationStack {
            List {
                Section("Preset Skills") {
                    ForEach(manager.presetSkills) { skill in
                        NavigationLink(skill.scheme.name) {
                            SkillsInfoView(skill: skill)
                        }
                    }
                }

                Section("Uploaded Skills") {
                    if manager.uploadedSkills.isEmpty {
                        Text("No Uploaded Skills Yet.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(manager.uploadedSkills) { skill in
                        NavigationLink(skill.scheme.name) {
                            SkillsInfoView(skill: skill)
                        }
                    }
                }
            }
            .navigationTitle("Skills")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddView = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showAddView) {
            SkillsAddView()
        }
    }
}
