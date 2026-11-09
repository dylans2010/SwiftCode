import SwiftUI
import UniformTypeIdentifiers
import AppKit

public struct FileImporterRepresentableView: NSViewRepresentable {
    public var allowedContentTypes: [UTType]
    public var allowsMultipleSelection: Bool = false
    public var onDocumentsPicked: ([URL]) -> Void

    public init(allowedContentTypes: [UTType], allowsMultipleSelection: Bool = false, onDocumentsPicked: @escaping ([URL]) -> Void) {
        self.allowedContentTypes = allowedContentTypes
        self.allowsMultipleSelection = allowsMultipleSelection
        self.onDocumentsPicked = onDocumentsPicked
    }

    public func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.allowedContentTypes = allowedContentTypes
            panel.allowsMultipleSelection = allowsMultipleSelection
            panel.canChooseDirectories = true
            panel.canChooseFiles = true

            if let window = view.window {
                panel.beginSheetModal(for: window) { response in
                    if response == .OK {
                        onDocumentsPicked(panel.urls)
                    } else {
                        onDocumentsPicked([])
                    }
                }
            } else {
                panel.begin { response in
                    if response == .OK {
                        onDocumentsPicked(panel.urls)
                    } else {
                        onDocumentsPicked([])
                    }
                }
            }
        }
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {}
}
