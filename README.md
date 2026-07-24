# Atlas — macOS 原生（SwiftUI）第一版骨架

黑白单色 + Apple 液态玻璃（Liquid Glass）的第一批设计 token 与关键组件。
这是"真原生重写"路线的起点：可在 Xcode 直接打开运行，用来验证"黑白 + 玻璃"的观感，再决定是否铺开。

## 环境要求（重要）

- **Xcode 26 以上**，**macOS 26（Tahoe）以上**。
- 液态玻璃用的是系统原生 API（`.glassEffect` / `GlassEffectContainer`），只存在于 macOS 26 SDK。
  代码里已用 `if #available(macOS 26.0, *)` 包住，低版本运行时降级为 `.ultraThinMaterial`；
  但**编译**仍需 macOS 26 SDK（即 Xcode 26）。用旧 Xcode 打开会报"找不到 glassEffect"。

## 打开方式

双击 `Atlas.xcodeproj` → 选 `My Mac` → Run（⌘R）。
工程用的是 Xcode 16+ 的"文件系统同步组"格式，`Atlas/` 目录下所有 `.swift` 会被自动纳入编译，
新增文件直接丢进去即可，无需手动改工程文件。

## 目录结构

```
Atlas/
  AtlasApp.swift            App 入口（暗色、隐藏标题栏窗口）
  RootView.swift            样例屏：把所有组件拼进真实布局
  DesignSystem/
    Theme.swift             黑白语义 token：色板/间距/圆角/字体 + 制图网格画布背景
    Glass.swift             液态玻璃统一封装 + 低版本降级（全站玻璃只从这里出）
  Components/
    GlassButton.swift       按钮：primary（白色实心）/ glass / ghost 三档
    GlassPanel.swift        通用玻璃面板容器（标题 + 内容 + 尾部动作）
    WorldObjectCard.swift    ★领域组件：世界对象卡
    SidebarShell.swift       App 壳：玻璃侧栏导航 + 内容区
  Models/
    WorldObject.swift       世界对象模型（类型/状态/版本/关联/AI 标注）+ 示例数据
```

## 这一版刻意定下的规则

1. **无主题色**。层次全靠单色灰阶 + 玻璃质感 + 排版权重。想引入单一强调色时，只改 `Theme.swift` 一处。
2. **类型/状态不靠颜色区分**，靠图标 + 文案 + 亮度（黑白系统的硬约束，也利于无障碍）。
3. **玻璃只从 `Glass.swift` 出**。相邻玻璃元素用 `AtlasGlassGroup`（= `GlassEffectContainer`）包起来融合。
4. **AI 辅助必须透明标注**（对象卡右下角的 "AI 辅助" 标）—— 对应 Atlas 红线。
5. 技术元数据（ID / 版本 / 坐标）一律等宽字体，正文用系统无衬线。

## 与旧资产的关系

- 旧的 `DESIGN-SYSTEM-BRIEF.md`（暗色 + 三 accent + 避免 glass）方向已作废，被本套黑白玻璃 token 取代。
- `build-world-企划创建板块` 的 React 代码 / 两份 PRD、`linking` 的评分文档 → 作为**功能规格参考**，
  逐块用 SwiftUI 重新实现，代码本身不迁移。

## 下一步候选（待确认）

- World Canvas 地图编辑器（重交互，程序化地形）→ SwiftUI `Canvas` / Metal 重写，是最大工作量。
- 对象详情侧栏、审核队列、公开页三视图（观众/申请者/成员/主催）。
- 把 Linking 评分引擎（三轴/递减/Polish）落成 Swift 逻辑层。
