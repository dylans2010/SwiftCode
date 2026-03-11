import SwiftUI

// MARK: - Extensions View

/// Central hub for managing SwiftCode Extensions. Users can install, delete,
/// enable, or disable Extensions. Supports search, filter, and sort.
/// Accessible directly from the Customize Toolbar.
struct ExtensionsView: View {
    @StateObject private var manager = ExtensionManager.shared
    @State private var searchText = ""
    @State private var selectedCategory: ExtensionManifest.ExtensionCategory? = nil
    @State private var sortOrder: SortOrder = .name
    @State private var showCreateSheet = false
    @State private var extensionToEdit: ExtensionManifest?
    @State private var extensionToDelete: ExtensionManifest?
    @State private var showDeleteConfirm = false

    enum SortOrder: String, CaseIterable {
        case name      = "Name"
        case category  = "Category"
        case installed = "Installed"
    }

    var filteredExtensions: [ExtensionManifest] {
        var result = manager.extensions

        // Filter by search
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText) ||
                $0.author.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Filter by category
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        // Sort
        switch sortOrder {
        case .name:
            result.sort { $0.name < $1.name }
        case .category:
            result.sort { $0.category.rawValue < $1.category.rawValue }
        case .installed:
            result.sort { $0.isInstalled && !$1.isInstalled }
        }

        return result
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.08, green: 0.08, blue: 0.12).ignoresSafeArea()

                Group {
                    if manager.isLoading && manager.extensions.isEmpty {
                        ProgressView("Loading Extensions…")
                            .tint(.orange)
                    } else if filteredExtensions.isEmpty {
                        emptyState
                    } else {
                        extensionList
                    }
                }
            }
            .navigationTitle("Extensions")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search extensions…")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Picker("Sort", selection: $sortOrder) {
                            ForEach(SortOrder.allCases, id: \.self) { order in
                                Text(order.rawValue).tag(order)
                            }
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                            .foregroundStyle(.orange)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            Task { await manager.scanExtensions() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(.orange)
                        }

                        Button {
                            showCreateSheet = true
                        } label: {
                            Image(systemName: "plus")
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateExtensionView()
            }
            .sheet(item: $extensionToEdit) { ext in
                EditExtensionView(extension: ext)
            }
            .confirmationDialog(
                "Delete "\(extensionToDelete?.name ?? "")"?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let ext = extensionToDelete {
                        try? manager.uninstallExtension(ext)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete the extension and remove it from the IDE.")
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Extension List

    private var extensionList: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Category filter bar
                categoryFilterBar
                    .padding(.vertical, 8)

                LazyVStack(spacing: 0) {
                    ForEach(filteredExtensions) { ext in
                        ExtensionRow(
                            ext: ext,
                            onToggle: { manager.toggleExtension(ext) },
                            onEdit: { extensionToEdit = ext },
                            onDelete: {
                                extensionToDelete = ext
                                showDeleteConfirm = true
                            }
                        )
                        Divider().opacity(0.1).padding(.leading, 60)
                    }
                }
            }
        }
    }

    // MARK: - Category Filter Bar

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "All", icon: "square.grid.2x2", selected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(ExtensionManifest.ExtensionCategory.allCases) { category in
                    filterChip(label: category.rawValue, icon: category.icon, selected: selectedCategory == category) {
                        selectedCategory = (selectedCategory == category) ? nil : category
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func filterChip(label: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(selected ? Color.orange.opacity(0.25) : Color.white.opacity(0.07), in: Capsule())
            .foregroundStyle(selected ? .orange : .secondary)
            .overlay(
                Capsule().stroke(selected ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 52))
                .foregroundStyle(.orange.opacity(0.5))
            Text(searchText.isEmpty ? "No Extensions Installed" : "No Results")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text(searchText.isEmpty
                 ? "Tap + to create your own extension, or install one from a folder."
                 : "Try a different search or filter.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            if searchText.isEmpty {
                Button {
                    showCreateSheet = true
                } label: {
                    Label("Create Extension", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Extension Row

struct ExtensionRow: View {
    let ext: ExtensionManifest
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(categoryColor(ext.category).opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: ext.category.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(categoryColor(ext.category))
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(ext.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("v\(ext.version)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.secondary.opacity(0.15), in: Capsule())

                    if ext.isUserCreated {
                        Text("custom")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.purple.opacity(0.15), in: Capsule())
                    }
                }

                Text(ext.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                // Capabilities
                if !ext.capabilities.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(ext.capabilities, id: \.self) { cap in
                                Text(cap.rawValue)
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(.blue.opacity(0.12), in: Capsule())
                            }
                        }
                    }
                }
            }

            Spacer()

            // Toggle
            Toggle("", isOn: .constant(ext.isEnabled))
                .labelsHidden()
                .tint(.orange)
                .onTapGesture { onToggle() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ext.isEnabled ? Color.orange.opacity(0.02) : Color.clear)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { onDelete() } label: {
                Label("Delete", systemImage: "trash")
            }

            if ext.isUserCreated {
                Button { onEdit() } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(.blue)
            }
        }
    }

    private func categoryColor(_ category: ExtensionManifest.ExtensionCategory) -> Color {
        switch category {
        case .editor:    return .blue
        case .tools:     return .orange
        case .themes:    return .pink
        case .languages: return .green
        case .ai:        return .purple
        case .build:     return .yellow
        case .testing:   return .teal
        case .other:     return .secondary
        }
    }
}
