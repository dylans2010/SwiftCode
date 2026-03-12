import SwiftUI

struct SkillsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = AgentSkillManager.shared
    @State private var showAddView = false
    @State private var searchText = ""
    @State private var selectedTag: String?

    private var allTags: [String] {
        let tags = manager.allSkills.flatMap { $0.scheme.tags }
        return Array(Set(tags)).sorted()
    }

    private var filteredPresets: [AgentSkillBundle] {
        filterSkills(manager.presetSkills)
    }

    private var filteredUploaded: [AgentSkillBundle] {
        filterSkills(manager.uploadedSkills)
    }

    private func filterSkills(_ skills: [AgentSkillBundle]) -> [AgentSkillBundle] {
        skills.filter { skill in
            let matchesSearch = searchText.isEmpty ||
                skill.scheme.name.localizedCaseInsensitiveContains(searchText) ||
                skill.scheme.summary.localizedCaseInsensitiveContains(searchText)
            let matchesTag = selectedTag == nil || skill.scheme.tags.contains(selectedTag!)
            return matchesSearch && matchesTag
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 12))
                        TextField("Search skills...", text: $searchText)
                            .font(.system(size: 14))
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.06))
                    )
                }
                .padding(.horizontal)
                .padding(.top, 8)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        tagPill("All", isSelected: selectedTag == nil) {
                            selectedTag = nil
                        }
                        ForEach(allTags, id: \.self) { tag in
                            tagPill(tag, isSelected: selectedTag == tag) {
                                selectedTag = selectedTag == tag ? nil : tag
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }

                List {
                    if !filteredPresets.isEmpty {
                        Section {
                            ForEach(filteredPresets) { skill in
                                NavigationLink {
                                    SkillsInfoView(skill: skill)
                                } label: {
                                    skillRow(skill)
                                }
                            }
                        } header: {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.orange)
                                Text("Built-in Skills (\(filteredPresets.count))")
                            }
                            .font(.caption.weight(.semibold))
                        }
                    }

                    if !filteredUploaded.isEmpty {
                        Section {
                            ForEach(filteredUploaded) { skill in
                                NavigationLink {
                                    SkillsInfoView(skill: skill)
                                } label: {
                                    skillRow(skill)
                                }
                            }
                        } header: {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundStyle(.blue)
                                Text("Uploaded Skills (\(filteredUploaded.count))")
                            }
                            .font(.caption.weight(.semibold))
                        }
                    }

                    if filteredPresets.isEmpty && filteredUploaded.isEmpty {
                        Section {
                            VStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 28))
                                    .foregroundStyle(.secondary)
                                Text("No skills match your search")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                        }
                    }
                }
            }
            .navigationTitle("Skills & Tools")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddView = true
                    } label: {
                        Label("Add", systemImage: "plus.circle.fill")
                    }
                }
            }
        }
        .sheet(isPresented: $showAddView) {
            SkillsAddView()
        }
    }

    private func tagPill(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.orange.opacity(0.2) : Color.white.opacity(0.06))
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 1)
                )
                .foregroundStyle(isSelected ? .orange : .secondary)
        }
        .buttonStyle(.plain)
    }

    private func skillRow(_ skill: AgentSkillBundle) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(skill.scheme.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("v\(skill.scheme.version)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text(skill.scheme.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack(spacing: 4) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.system(size: 9))
                    .foregroundStyle(.orange)
                Text("\(skill.scheme.recommendedTools.count) tools")
                    .font(.caption2)
                    .foregroundStyle(.orange)

                ForEach(skill.scheme.tags.prefix(3), id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 9))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.12), in: Capsule())
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
