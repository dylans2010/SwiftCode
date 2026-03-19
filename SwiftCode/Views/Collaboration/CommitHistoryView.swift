import SwiftUI

struct CommitHistoryView: View {
    @ObservedObject var manager: CollaborationManager

    var body: some View {
        CommitManagerView(manager: manager, actorID: UIDevice.current.name)
    }
}
