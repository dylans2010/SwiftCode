import Foundation
import YcodeIDECore
import SwiftCodeSDK
import SwiftCodeGitHub

public typealias Project = YcodeIDECore.Project
public typealias ProjectSessionStore = YcodeIDECore.ProjectSessionStore



extension GitFileStatus: Identifiable {
    public var id: String { path }
}



extension GitHubIssue: Identifiable {}


extension GitBranch: Identifiable {
    public var id: String { "\(isRemote ? "remote" : "local"):\(name)" }
}



extension GitBranch {
    public var trackingRemote: String? { nil }
}
