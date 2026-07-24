//
//  WorldMapCanvasView.swift
//  真正的世界地图画布 —— 复用已验证的 React 地图编辑器（地形雕刻、
//  海岸线生成、锚点/关联/区域标注），以自包含 HTML 形式装进 WKWebView，
//  与星图同一套装载方式。创建世界与管理世界都进入这里。
//
//  资源：Resources/atlas-mapcanvas.html（离线自包含，含 React + d3-contour + simplex-noise）。
//  桥接：网页通过 window.webkit.messageHandlers.atlasBridge 回传 exit / save。
//

import SwiftUI
import WebKit

struct WorldMapCanvasView: NSViewRepresentable {
    /// "create"（空白起步）或 "manage"（管理已有世界）。目前两者都从空白地图开始。
    var mode: String = "create"
    var onExit: () -> Void = {}
    var onSave: (_ locations: Int) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(onExit: onExit, onSave: onSave)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "atlasBridge")
        // 在页面脚本执行前注入模式标记，供编辑器读取。
        let modeScript = WKUserScript(
            source: "window.ATLAS_MODE=\"\(mode)\";",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        controller.addUserScript(modeScript)
        configuration.userContentController = controller

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
                "<body style='background:#dfe4e2;font-family:system-ui;padding:40px'>地图资源缺失：atlas-mapcanvas.html</body>",
                baseURL: nil
            )
        }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onExit = onExit
        context.coordinator.onSave = onSave
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "atlasBridge")
    }

    private var resourceURL: URL? {
        Bundle.main.url(forResource: "atlas-mapcanvas", withExtension: "html", subdirectory: "Resources")
        ?? Bundle.main.url(forResource: "atlas-mapcanvas", withExtension: "html")
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        var onExit: () -> Void
        var onSave: (_ locations: Int) -> Void

        init(onExit: @escaping () -> Void, onSave: @escaping (_ locations: Int) -> Void) {
            self.onExit = onExit
            self.onSave = onSave
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "atlasBridge",
                  let payload = message.body as? [String: Any],
                  let type = payload["type"] as? String else { return }
            switch type {
            case "exit":
                onExit()
            case "save":
                let locations = payload["locations"] as? Int ?? 0
                onSave(locations)
            default:
                break
            }
        }
    }
}
