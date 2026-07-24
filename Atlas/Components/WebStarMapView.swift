import SwiftUI
import WebKit

struct WebStarMapView: NSViewRepresentable {
    var onOpenWorld: (String) -> Void

    private static let bridge = Bridge()
    private static var cachedWebView: WKWebView?

    func makeNSView(context: Context) -> WKWebView {
        Self.bridge.onOpenWorld = onOpenWorld

        if let cachedWebView = Self.cachedWebView {
            return cachedWebView
        }

        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(Self.bridge, name: "atlasBridge")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsMagnification = false

        if let resourceURL {
            webView.loadFileURL(
                resourceURL,
                allowingReadAccessTo: resourceURL.deletingLastPathComponent()
            )
        } else {
            webView.loadHTMLString(
                "<body style='background:#05050a;color:white;font-family:system-ui'>Star map resources are missing.</body>",
                baseURL: nil
            )
        }

        Self.cachedWebView = webView
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        Self.bridge.onOpenWorld = onOpenWorld
    }

    private var resourceURL: URL? {
        Bundle.main.url(
            forResource: "atlas-starmap",
            withExtension: "html",
            subdirectory: "Resources"
        ) ?? Bundle.main.url(
            forResource: "atlas-starmap",
            withExtension: "html"
        )
    }

    final class Bridge: NSObject, WKScriptMessageHandler {
        var onOpenWorld: ((String) -> Void)?

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "atlasBridge",
                  let payload = message.body as? [String: Any],
                  payload["type"] as? String == "openWorld",
                  let name = payload["name"] as? String else {
                return
            }
            onOpenWorld?(name)
        }
    }
}
