import Foundation
import SwiftUI
import YcodeBuild
import YcodeIDECore
import YcodeIDEShell
import YcodeUI

public struct WorkspaceToolbarView: View {
    @Bindable public var model: WorkspaceShellModel
    public var app: ShellAppModel
    @Environment(\.colorScheme) private var scheme

    public init(model: WorkspaceShellModel, app: ShellAppModel) {
        self.model = model
        self.app = app
    }

    public var body: some View {
        let c = ShellColors(scheme)
        HStack(spacing: 8) {
            // Left Group: Sidebar toggle, Assistant toggle, Git branch / project selector
            NavigatorToolbar(model: model)
                .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 8)

            // Center Group: Scheme & Destination capsule, Run & Stop, Build status
            CenterToolbar(model: model, app: app)
                .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 8)

            // Right Group: Library, Customize Toolbar, Editor Modes, Inspector Toggle
            InspectorToolbar(model: model)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 8)
        .frame(height: CGFloat(WorkspaceChrome.toolbarHeight))
        .background(c.sidebar.opacity(0.85))
    }
}
