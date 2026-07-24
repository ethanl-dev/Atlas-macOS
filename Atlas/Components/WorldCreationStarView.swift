//
//  WorldCreationStarView.swift
//  创建世界仪式的背景星场 —— 复用星图同一套 three.js 观感，
//  但只保留一颗"正在诞生的世界之星"。glow 由仪式进度驱动：
//  作者每前进一步，星就更亮一分，直到最后被点亮。
//

import SwiftUI
import WebKit

struct WorldCreationStarView: NSViewRepresentable {
    /// 0…1：世界之星的亮度，随仪式推进增长。
    var glow: Double

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsMagnification = false
        context.coordinator.webView = webView

        if let resourceURL {
            webView.loadFileURL(
                resourceURL,
                allowingReadAccessTo: resourceURL.deletingLastPathComponent()
            )
        } else {
            webView.loadHTMLString(
                "<body style='background:#09090b'></body>",
                baseURL: nil
            )
        }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.apply(glow: glow)
    }

    private var resourceURL: URL? {
        Bundle.main.url(forResource: "atlas-creation", withExtension: "html", subdirectory: "Resources")
        ?? Bundle.main.url(forResource: "atlas-creation", withExtension: "html")
    }

    final class Coordinator {
        weak var webView: WKWebView?
        private var lastGlow: Double = -1

        func apply(glow: Double) {
            guard abs(glow - lastGlow) > 0.001 else { return }
            lastGlow = glow
            let js = "window.atlasCreation && window.atlasCreation.setGlow(\(glow));"
            webView?.evaluateJavaScript(js, completionHandler: nil)
        }
    }
}
