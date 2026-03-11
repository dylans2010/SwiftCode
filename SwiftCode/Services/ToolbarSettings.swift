import SwiftUI
import Combine

/// Shared settings for the toolbar and editor to coordinate UI state
/// such as word wrap and the search bar visibility.
class ToolbarSettings: ObservableObject {
    static let shared = ToolbarSettings()

    @Published var wordWrap: Bool = false
    @Published var showSearchBar: Bool = false
    @AppStorage("com.swiftcode.toolbar.showToolNames") var showToolNames: Bool = true

    private init() {}
}
