import AppKit
import SwiftUI
import SwiftCodeExtensions









@MainActor
public final class ExtensionPermissionPresenter {
    public static let shared = ExtensionPermissionPresenter()

    private var observer: NSObjectProtocol?

    private init() {}

    public func install() {
        ExtensionPermissionApprovalCenter.shared.hasPresenter = true
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: ExtensionPermissionApprovalCenter.pendingRequestDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.presentPending() }
        }
    }

    private func presentPending() {
        let center = ExtensionPermissionApprovalCenter.shared
        guard let request = center.pendingRequest else { return }
        let alert = NSAlert()
        alert.messageText = "Extension \(request.extensionId) wants permission"
        alert.informativeText = "Capability: \(request.capability.displayName) (\(request.capability.riskLevel) risk)\n\n\(request.reason)"
        alert.addButton(withTitle: "Allow")
        alert.addButton(withTitle: "Deny")
        if !request.capability.isGrantable { alert.buttons.first?.isEnabled = false }
        let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first
        if let window, window.isVisible {
            alert.beginSheetModal(for: window) { response in
                center.answer(id: request.id, approved: response == .alertFirstButtonReturn)
            }
        } else {
            let response = alert.runModal()
            center.answer(id: request.id, approved: response == .alertFirstButtonReturn)
        }
    }
}
