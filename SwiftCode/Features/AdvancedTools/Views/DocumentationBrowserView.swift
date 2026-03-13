import SwiftUI
import WebKit
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct DocumentationBrowserView: View {
    @State private var query = "SwiftUI/View"
    @State private var currentURL = URL(string: "https://developer.apple.com/documentation/swiftui")!

    var body: some View {
        AdvancedToolScreen(title: "Documentation Browser") {
            AdvancedToolCard(title: "Apple Developer Docs", subtitle: "JavaScript-enabled rendering for dynamic pages") {
                HStack {
                    TextField("Search API (e.g. SwiftUI/View)", text: $query)
                        .textFieldStyle(.roundedBorder)
                    Button("Search", action: performSearch)
                        .buttonStyle(.borderedProminent)
                }

                DocsWebView(url: currentURL)
                    .frame(minHeight: 600)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private func performSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if trimmed.lowercased().hasPrefix("http"), let url = URL(string: trimmed) {
            currentURL = url
            return
        }

        let safePath = trimmed
            .replacingOccurrences(of: " ", with: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased()
        currentURL = URL(string: "https://developer.apple.com/documentation/\(safePath)")!
    }
}

private struct DocsWebView: PlatformViewRepresentable {
    let url: URL

    func makePlatformView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.load(URLRequest(url: url))
        return webView
    }

    func updatePlatformView(_ webView: WKWebView, context: Context) {
        guard webView.url != url else { return }
        webView.load(URLRequest(url: url))
    }
}

#if canImport(UIKit)
private typealias PlatformViewRepresentable = UIViewRepresentable

private extension DocsWebView {
    func makeUIView(context: Context) -> WKWebView {
        makePlatformView(context: context)
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        updatePlatformView(webView, context: context)
    }
}
#elseif canImport(AppKit)
private typealias PlatformViewRepresentable = NSViewRepresentable

private extension DocsWebView {
    func makeNSView(context: Context) -> WKWebView {
        makePlatformView(context: context)
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        updatePlatformView(webView, context: context)
    }
}
#endif
