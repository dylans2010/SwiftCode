import SwiftUI
import AppKit
import YcodeIDECore
import YcodeRelease
import YcodeAssistant

public struct Style26WelcomeView: View {
    public static let windowSize = NSSize(width: 800, height: 490)

    public var onOpenSelected: (URL) -> Void
    public var onCreateNewFile: () -> Void
    public var onCloneGitRepo: () -> Void
    public var onChooseTemplate: () -> Void
    public var onOpenFileOrFolder: () -> Void
    public var onClose: () -> Void

    @ObservedObject private var iconManager = AppIconManager.shared
    @State private var recentURLs: [URL] = []
    @State private var selectedURL: URL?
    @State private var hoveredURL: URL?

    public init(
        onOpenSelected: @escaping (URL) -> Void = { _ in },
        onCreateNewFile: @escaping () -> Void = {},
        onCloneGitRepo: @escaping () -> Void = {},
        onChooseTemplate: @escaping () -> Void = {},
        onOpenFileOrFolder: @escaping () -> Void = {},
        onClose: @escaping () -> Void = {}
    ) {
        self.onOpenSelected = onOpenSelected
        self.onCreateNewFile = onCreateNewFile
        self.onCloneGitRepo = onCloneGitRepo
        self.onChooseTemplate = onChooseTemplate
        self.onOpenFileOrFolder = onOpenFileOrFolder
        self.onClose = onClose
    }

    public var body: some View {
        HStack(spacing: 0) {
            leftPane
                .frame(width: 460)

            Divider()
                .overlay(Color.white.opacity(0.06))

            rightPane
                .frame(width: 340)
        }
        .frame(width: Self.windowSize.width, height: Self.windowSize.height)
        .background(Color(red: 0.07, green: 0.10, blue: 0.18))
        .onAppear {
            reloadRecents()
            NotificationCenter.default.addObserver(forName: RecentProjects.didChange, object: nil, queue: .main) { _ in
                reloadRecents()
            }
        }
    }

    private var leftPane: some View {
        ZStack(alignment: .topLeading) {
            Color(red: 0.08, green: 0.11, blue: 0.20)
                .ignoresSafeArea()

            Button(action: onClose) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 24, height: 24)
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.75))
                }
            }
            .buttonStyle(.plain)
            .padding(16)
            .help("Close")

            VStack(spacing: 0) {
                Spacer().frame(height: 38)

                // App Icon (user picked)
                Group {
                    if let img = iconManager.currentIconImage ?? NSApp.applicationIconImage {
                        Image(nsImage: img)
                            .resizable()
                    } else {
                        Image(nsImage: ProductIcon.image)
                            .resizable()
                    }
                }
                .aspectRatio(contentMode: .fit)
                .frame(width: 124, height: 124)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .shadow(color: Color.black.opacity(0.45), radius: 14, x: 0, y: 7)

                // App Name
                Text("SwiftCode")
                    .font(.system(size: 34, weight: .bold, design: .default))
                    .foregroundStyle(.white)
                    .padding(.top, 16)

                // Version line pulled from CFBundleVersion
                Text(versionText)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.65))
                    .padding(.top, 4)

                // Action buttons
                VStack(spacing: 10) {
                    actionButton(title: "Create New File...", icon: "plus.square", action: onCreateNewFile)
                    actionButton(title: "Clone Git Repository...", icon: "arrow.down.to.line.compact", action: onCloneGitRepo)
                    actionButton(title: "Choose From Template...", icon: "square.grid.2x2", action: onChooseTemplate)
                    actionButton(title: "Open File or Folder...", icon: "folder", action: onOpenFileOrFolder)
                }
                .padding(.horizontal, 36)
                .padding(.top, 24)

                Spacer(minLength: 16)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var versionText: String {
        let bundleVersion = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String)
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
            ?? SwiftCodeRelease.version
        let marketingVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
            ?? SwiftCodeRelease.marketingVersion
        if !marketingVersion.isEmpty && marketingVersion != bundleVersion {
            return "Version \(marketingVersion) (\(bundleVersion))"
        } else {
            return "Version \(bundleVersion)"
        }
    }

    @ViewBuilder
    private func actionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Style26ButtonCard(title: title, icon: icon)
        }
        .buttonStyle(.plain)
    }

    private var rightPane: some View {
        ZStack {
            Color(red: 0.06, green: 0.14, blue: 0.30)
                .ignoresSafeArea()

            if recentURLs.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "folder")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.white.opacity(0.25))
                    Text("No Recent Projects")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.45))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(recentURLs, id: \.self) { url in
                            Style26RecentItemRow(
                                url: url,
                                isSelected: selectedURL == url,
                                onSelect: { selectedURL = url },
                                onOpen: { onOpenSelected(url) },
                                onRemove: { removeRecent(url) }
                            )
                        }
                    }
                    .padding(12)
                }
            }
        }
    }

    private func reloadRecents() {
        let urls = RecentProjects.shared.urls
        recentURLs = urls
        if selectedURL == nil || !urls.contains(where: { $0 == selectedURL }) {
            selectedURL = urls.first
        }
    }

    private func removeRecent(_ url: URL) {
        RecentProjects.shared.remove(url)
        reloadRecents()
    }
}

private struct Style26ButtonCard: View {
    let title: String
    let icon: String
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.9))
                .frame(width: 22)

            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)

            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 42)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.white.opacity(isHovered ? 0.14 : 0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color.white.opacity(isHovered ? 0.15 : 0.08), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .onHover { isHovered = $0 }
    }
}

private struct Style26RecentItemRow: View {
    let url: URL
    let isSelected: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void
    let onRemove: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Image(nsImage: rowIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(RecentProjects.displayName(url))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(RecentProjects.folderText(url))
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.white.opacity(0.55))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color(red: 0.12, green: 0.40, blue: 0.88) : (isHovered ? Color.white.opacity(0.06) : Color.clear))
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .simultaneousGesture(TapGesture(count: 2).onEnded {
            onOpen()
        })
        .contextMenu {
            Button("Open") { onOpen() }
            Divider()
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url.path, forType: .string)
            }
            Divider()
            Button("Remove from Recents") {
                onRemove()
            }
        }
    }

    private var rowIcon: NSImage {
        let container = RecentProjects.containerURL(url)
        return NSWorkspace.shared.icon(forFile: container.path)
    }
}
