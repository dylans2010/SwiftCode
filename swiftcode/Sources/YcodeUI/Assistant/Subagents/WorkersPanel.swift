import AppKit
import SwiftUI
import YcodeAssistant




@MainActor
public enum WorkersPanel {
    
    
    public static func present(from presenter: NSViewController?) {
        let host = NSHostingController(rootView: WorkersMainView())
        host.sizingOptions = [.preferredContentSize]
        if let presenter, presenter.view.window != nil {
            presenter.presentAsSheet(host)
        } else if let content = NSApp.keyWindow?.contentViewController {
            content.presentAsSheet(host)
        }
    }

    
    public static func buttonTitle() -> String {
        let state = WorkerRuntimeState.shared
        let active = state.activeWorkers.count
        if active > 0 { return "Workers · \(active)" }
        let total = state.allWorkers.count
        return total > 0 ? "Workers · \(total)" : "Workers"
    }
}



@MainActor
public final class WorkersStripView: NSView {
    private let hosting: NSHostingView<WorkersOnAssistView>

    public init() {
        hosting = NSHostingView(rootView: WorkersOnAssistView())
        hosting.sizingOptions = [.intrinsicContentSize]
        super.init(frame: .zero)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: topAnchor),
            hosting.leadingAnchor.constraint(equalTo: leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: trailingAnchor),
            hosting.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        isHidden = WorkerRuntimeState.shared.allWorkers.isEmpty
        observe()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func observe() {
        withObservationTracking {
            _ = WorkerRuntimeState.shared.allWorkers.isEmpty
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isHidden = WorkerRuntimeState.shared.allWorkers.isEmpty
                self.observe()
            }
        }
    }
}
