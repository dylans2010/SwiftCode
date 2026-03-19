import SwiftUI

struct CollaborationDashboardView: View {
    @ObservedObject var manager: CollaborationManager

    var body: some View {
        CollaborationMainView(manager: manager)
    }
}
