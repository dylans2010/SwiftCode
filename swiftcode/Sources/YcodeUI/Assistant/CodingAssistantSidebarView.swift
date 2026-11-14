import AppKit
import SwiftUI
import YcodeAssistant
import YcodeIDECore

public struct CodingAssistantSidebarView: View {
    public let model: CodingAssistantModel
    @State private var inputText: String = ""
    @State private var showTodoList: Bool = true

    public init(model: CodingAssistantModel) {
        self.model = model
    }

    public var body: some View {
        CodingAssistantRepresentable(model: model)
            .edgesIgnoringSafeArea(.all)
    }
}

public struct CodingAssistantRepresentable: NSViewControllerRepresentable {
    public let model: CodingAssistantModel

    public init(model: CodingAssistantModel) {
        self.model = model
    }

    public func makeNSViewController(context: Context) -> CodingAssistantViewController {
        CodingAssistantViewController(model: model)
    }

    public func updateNSViewController(_ nsViewController: CodingAssistantViewController, context: Context) {
        
    }
}
