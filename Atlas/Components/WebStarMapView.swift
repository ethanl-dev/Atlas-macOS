import SwiftUI
import WebKit

struct WebStarMapView: NSViewRepresentable {
    var onOpenWorld: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onOpenWorld: onOpenWorld)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(context.coordinator, name: "atlasBridge")

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

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onOpenWorld = onOpenWorld
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "atlasBridge")
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

    final class Coordinator: NSObject, WKScriptMessageHandler {
        var onOpenWorld: (String) -> Void

        init(onOpenWorld: @escaping (String) -> Void) {
            self.onOpenWorld = onOpenWorld
        }

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
            onOpenWorld(name)
        }
    }
}
