import SwiftUI

struct BranchManagementView: View {
    @ObservedObject var manager: CollaborationManager

    var body: some View {
        BranchGraphView(manager: manager)
    }
}
