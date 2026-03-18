import UIKit
import Messages

class MessagesViewController: MSMessagesAppViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let label = UILabel()
        label.text = "Hello iMessage!"
        label.textAlignment = .center
        label.frame = view.bounds
        view.addSubview(label)
    }
}