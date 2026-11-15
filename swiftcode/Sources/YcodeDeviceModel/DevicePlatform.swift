import Foundation

public enum DevicePlatform: String, Sendable, CaseIterable, Hashable {
    case iOS = "iOS"
    case iPadOS = "iPadOS"
    case watchOS = "watchOS"
    case tvOS = "tvOS"
    case visionOS = "visionOS"
    case macOS = "macOS"
    case unknown = "Unknown"

    public init(parsing raw: String?) {
        guard let raw else {
            self = .unknown
            return
        }
        let lower = raw.lowercased()
        if lower.contains("xros") || lower.contains("vision") {
            self = .visionOS
        } else if lower.contains("watch") {
            self = .watchOS
        } else if lower.contains("tvos") || lower == "tv" || lower.contains("appletv") {
            self = .tvOS
        } else if lower.contains("macos") || lower.contains("mac os") {
            self = .macOS
        } else if lower.contains("ipad") {
            self = .iPadOS
        } else if lower.contains("ios") || lower.contains("iphone") {
            self = .iOS
        } else {
            self = .unknown
        }
    }

    public init(runtimeIdentifier: String) {
        let cleaned = runtimeIdentifier.replacingOccurrences(of: "com.apple.CoreSimulator.SimRuntime.", with: "")
        let head = cleaned.split(separator: "-").first.map(String.init) ?? cleaned
        self.init(parsing: head)
    }
}
