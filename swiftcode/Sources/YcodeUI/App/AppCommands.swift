import AppKit
import YcodeIDECore
import SwiftUI
import YcodeAssistant
import SwiftCodeSDKStudio
import YcodeDecompiler

@MainActor
public final class AppCommands: NSObject {
    public static let shared = AppCommands()

    public enum Links {
        public static let developerDocumentation = URL(string: "https://developer.apple.com/documentation/")!
        public static let humanInterfaceGuidelines = URL(string: "https://developer.apple.com/design/human-interface-guidelines/")!
        public static let swiftBook = URL(string: "https://docs.swift.org/swift-book/")!
        public static let moreDeveloperTools = URL(string: "https://developer.apple.com/download/all/")!
        public static func documentationSearch(_ q: String) -> URL? {
            var c = URLComponents(string: "https://developer.apple.com/search/")!
            c.queryItems = [URLQueryItem(name: "q", value: q)]
            return c.url
        }
    }

    public static var open: (URL) -> Void = { NSWorkspace.shared.open($0) }

    static let actions: Set<String> = [
        "showDeveloperDocumentation:", "showHumanInterfaceGuidelines:", "showSwiftBook:", "openMoreDeveloperTools:",
        "openDeveloperTool:", "showDownloads:", "compareFiles:", "showAboutWindow:", "showSwiftCodeHelp:", "showReleaseNotes:", "reportBug:",
        "openVisualUIBuilder:", "openCodingDictionary:", "openDeviceConnect:", "exportIPA:", "createWorkflow:", "manageWorkflows:", "openCIWorkflows:",
        "openTerminal:", "openTerminalAtLocation:", "openRepositoryExplorer:", "openVirtualization:", "openSCToolsDrawer:", "showSDKStudio:", "openSourceControlWorkspace:", "openDecompiler:",
        "showExtensionMarketplace:", "showAssetManager:", "showTestTools:", "showDebuggingTools:", "showChooseModel:",
    ]

    public static func handles(_ action: String) -> Bool { actions.contains(action) }

    private var activeWorkspaceURL: URL {
        ProjectSessionStore.shared.activeProject?.directoryURL ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    @objc public func showDeveloperDocumentation(_ sender: Any?) { Self.open(Links.developerDocumentation) }
    @objc public func showHumanInterfaceGuidelines(_ sender: Any?) { Self.open(Links.humanInterfaceGuidelines) }
    @objc public func showSwiftBook(_ sender: Any?) { Self.open(Links.swiftBook) }
    @objc public func showAboutWindow(_ sender: Any?) { AboutWindowController.shared.showWindow(sender) }
    @objc public func showSwiftCodeHelp(_ sender: Any?) { Self.open(ProductIdentity.helpURL) }
    @objc public func showReleaseNotes(_ sender: Any?) { Self.open(ProductIdentity.releasesURL) }
    @objc public func reportBug(_ sender: Any?) { Self.open(ProductIdentity.bugReportURL()) }
    @objc public func openMoreDeveloperTools(_ sender: Any?) { Self.open(Links.moreDeveloperTools) }

    @objc public func openDeveloperTool(_ sender: Any?) {
        guard let url = (sender as? NSMenuItem)?.representedObject as? URL else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    @objc public func showDownloads(_ sender: Any?) { SettingsWindowController.shared.show(pane: "Components") }

    @objc public func openVisualUIBuilder(_ sender: Any?) {
        VisualUIBuilderWindowManager.shared.showWindow()
    }

    @objc public func openCodingDictionary(_ sender: Any?) {
        CodingDictionaryWindowManager.shared.showWindow()
    }

    @objc public func openDeviceConnect(_ sender: Any?) {
        DeviceConnectWindowManager.shared.showWindow()
    }

    @objc public func exportIPA(_ sender: Any?) {
        IPABuildWindowManager.shared.showWindow()
    }

    @objc public func createWorkflow(_ sender: Any?) {
        CIWorkflowWindowManager.shared.showWindow(workspaceFolder: activeWorkspaceURL)
    }

    @objc public func manageWorkflows(_ sender: Any?) {
        CIWorkflowWindowManager.shared.showWindow(workspaceFolder: activeWorkspaceURL)
    }

    @objc public func openCIWorkflows(_ sender: Any?) {
        CIWorkflowWindowManager.shared.showWindow(workspaceFolder: activeWorkspaceURL)
    }

    @objc public func openTerminal(_ sender: Any?) {
        TerminalWindowManager.shared.showWindow(workspaceFolder: activeWorkspaceURL)
    }

    @objc public func openTerminalAtLocation(_ sender: Any?) {
        TerminalWindowManager.shared.showWindow(workspaceFolder: activeWorkspaceURL)
    }

    @objc public func openRepositoryExplorer(_ sender: Any?) {
        RepositoryExplorerWindowManager.shared.showWindow(workspaceFolder: activeWorkspaceURL)
    }

    @objc public func openVirtualization(_ sender: Any?) {
        VirtualizationWindowManager.shared.showWindow()
    }

    @objc public func openSourceControlWorkspace(_ sender: Any?) {
        SourceControlWindowManager.shared.showWindow(workspaceFolder: activeWorkspaceURL)
    }

    @objc public func openDecompiler(_ sender: Any?) {
        DecompilerWindowManager.shared.showWindow()
    }

    @objc public func showExtensionMarketplace(_ sender: Any?) { FeaturesWindowManager.shared.showExtensionMarketplace() }
    @objc public func showAssetManager(_ sender: Any?) { FeaturesWindowManager.shared.showAssetManager() }
    @objc public func showTestTools(_ sender: Any?) {
        FeaturesWindowManager.shared.showTestTools(project: ProjectSessionStore.shared.activeProject)
    }
    @objc public func showDebuggingTools(_ sender: Any?) { FeaturesWindowManager.shared.showDebuggingTools() }
    @objc public func showChooseModel(_ sender: Any?) { FeaturesWindowManager.shared.showChooseModel() }

    @objc public func showSDKStudio(_ sender: Any?) {
        SDKStudioWindowManager.shared.openStudio()
    }

    @objc public func openSCToolsDrawer(_ sender: Any?) {
        SCToolsWindowManager.shared.showWindow(workspaceFolder: activeWorkspaceURL)
    }
}

extension AppDelegate {
    @objc public func closeTab(_ sender: Any?) { NSApp.keyWindow?.performClose(sender) }

    @objc public func showBehaviorsSettings(_ sender: Any?) { SettingsWindowController.shared.show(pane: "Behaviors") }
}

private struct EditorViewHelpCommands: Commands {
    @CommandsBuilder
    var body: some Commands {
        CommandGroup(after: .textEditing) {
            Button("Go to Line...") {
                NotificationCenter.default.post(name: .toolbarToolActivated, object: nil, userInfo: ["toolID": "go_to_line"])
            }
            .keyboardShortcut("l", modifiers: [.command])

            Button("Find...") {
                NotificationCenter.default.post(name: .toolbarToolActivated, object: nil, userInfo: ["toolID": "code_search"])
            }
            .keyboardShortcut("f", modifiers: [.command])

            Button("Format Code") {
                NotificationCenter.default.post(name: NSNotification.Name("FormatCode"), object: nil)
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])

            Divider()

            Button("Next Tab") {
                NotificationCenter.default.post(name: NSNotification.Name("NextTab"), object: nil)
            }
            .keyboardShortcut("}", modifiers: [.command, .shift])

            Button("Previous Tab") {
                NotificationCenter.default.post(name: NSNotification.Name("PreviousTab"), object: nil)
            }
            .keyboardShortcut("{", modifiers: [.command, .shift])
        }

        CommandGroup(after: .toolbar) {
            Divider()

            Button("Customize Toolbar...") {
                SwiftCodeToolbarDelegate.presentCustomizationPalette()
            }

            Divider()

            Button("Coding Tools") {
                NotificationCenter.default.post(
                    name: Notification.Name("TriggerCodingToolsContextAction"),
                    object: nil,
                    userInfo: [
                        "action": CodingToolsUI.CodingAction.refactor,
                        "code": "",
                        "filePath": ""
                    ]
                )
            }
        }

        CommandGroup(replacing: .help) {
            Button("SwiftCode Documentation") {
                NotificationCenter.default.post(name: .toolbarToolActivated, object: nil, userInfo: ["toolID": "documentation_browser"])
            }
            Button("Diagnostics") {
                NotificationCenter.default.post(name: .toolbarToolActivated, object: nil, userInfo: ["toolID": "error_diagnostics"])
            }
        }
    }
}
