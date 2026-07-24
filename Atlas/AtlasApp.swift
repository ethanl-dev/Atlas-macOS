//
//  AtlasApp.swift
//  Atlas — 原创角色企划的世界基础设施
//
//  设计方向：纯黑白 + Apple 液态玻璃（Liquid Glass）。
//  无主题色，层次全部由单色灰阶 + 玻璃质感承担。
//  需 Xcode 26 / macOS 26（Tahoe）—— 液态玻璃为系统原生 API。
//

import SwiftUI

@main
struct AtlasApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .frame(minWidth: 960, minHeight: 640)
                .preferredColorScheme(.dark)
                .tint(.white)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1160, height: 760)
    }
}
