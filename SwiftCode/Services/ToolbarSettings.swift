import SwiftUI
import Combine

/// Shared settings for the toolbar and editor to coordinate UI state
/// such as word wrap and the search bar visibility.
class ToolbarSettings: ObservableObject {
    static let shared = ToolbarSettings()

    @Published var wordWrap: Bool = true
    @Published var showSearchBar: Bool = false

    private init() {}
}
