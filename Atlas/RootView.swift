import SwiftUI

struct RootView: View {
    @StateObject private var model = AtlasAppModel()
    @StateObject private var iris = IrisTransition()

    // 创建世界 从星图右上角的按钮绽放；返回星图从编辑器左上角的返回按钮收拢。
    private let createOrigin = UnitPoint(x: 0.9, y: 0.08)
    private let returnOrigin = UnitPoint(x: 0.04, y: 0.06)

    var body: some View {
        ZStack {
            Group {
                if model.creatingWorld {
                    // 创建世界 = 进入 World Canvas（组件库 + 自由画布 + 可编辑详情卡），地图只是底盘之一
                    WorldBuilderCanvas(
                        model: model,
                        mode: "create",
                        worldName: "未命名世界",
                        onExit: {
                            iris.run(from: returnOrigin) { model.creatingWorld = false }
                        }
                    )
                    .ignoresSafeArea()
                } else if model.destination == .discover {
                    DiscoverView(model: model) {
                        iris.run(from: createOrigin) { model.creatingWorld = true }
                    }
                } else {
                    projectShell
                }
            }

            IrisCurtain(iris: iris)
        }
        .sheet(item: $model.activeSheet) { sheet in
            sheetView(sheet)
        }
    }

    private var projectShell: some View {
        NavigationSplitView {
            AtlasAppSidebar(model: model)
                .navigationSplitViewColumnWidth(min: 210, ideal: 224, max: 252)
        } detail: {
            destinationView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .top) {
                    if let toast = model.toast {
                        ToastView(message: toast)
                            .padding(.top, AtlasSpacing.l)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .animation(.snappy(duration: 0.24), value: model.toast)
        }
        .navigationTitle("")
    }

    @ViewBuilder
    private var destinationView: some View {
        switch model.destination {
        case .discover:
            EmptyView()
        case .worlds:
            WorldsHomeView(model: model)
        case .overview:
            ProjectOverviewView(model: model)
        case .canvas:
            WorldBuilderCanvas(
                model: model,
                mode: "manage",
                worldName: model.activeWorld.name,
                onExit: { model.destination = .overview }
            )
            .ignoresSafeArea()
            .id(model.activeWorldID)
        case .wiki:
            WorldWikiView(model: model)
        case .assets:
            AssetLibraryView(model: model)
        case .tasks:
            InteractionHubView(model: model)
        case .review:
            ReviewQueueView(model: model)
        case .publicPreview:
            PublicProjectView(model: model)
        case .inbox:
            InboxView(model: model)
        }
    }

    @ViewBuilder
    private func sheetView(_ sheet: AtlasSheet) -> some View {
        switch sheet {
        case .createWorld:
            // 创建世界已改为全屏地图编辑器（model.creatingWorld），此 sheet 不再使用。
            EmptyView()
        case .submitWork:
            SubmitWorkSheet(model: model)
        case .publish:
            PublishCheckSheet(model: model)
        case .application:
            ApplicationFlowSheet(model: model)
        case .newTask:
            NewTaskSheet(model: model)
        case .objectEditor:
            ObjectEditorSheet(model: model)
        }
    }
}

private struct ToastView: View {
    var message: String

    var body: some View {
        HStack(spacing: AtlasSpacing.s) {
            Image(systemName: "checkmark.circle")
            Text(message)
                .font(AtlasFont.label)
        }
        .foregroundStyle(AtlasColor.textPrimary)
        .padding(.horizontal, AtlasSpacing.m)
        .padding(.vertical, AtlasSpacing.s)
        .atlasGlass(Capsule())
        .overlay(Capsule().stroke(AtlasColor.borderDefault))
        .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
    }
}

#Preview {
    RootView()
        .frame(width: 1240, height: 800)
        .preferredColorScheme(.dark)
}
