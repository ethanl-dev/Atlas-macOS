import SwiftUI

struct RootView: View {
    @StateObject private var model = AtlasAppModel()
    @StateObject private var iris = IrisTransition()

    // 创建世界 从星图右上角按钮绽放；返回从编辑器左上角返回按钮收拢。
    private let createOrigin = UnitPoint(x: 0.9, y: 0.08)
    private let returnOrigin = UnitPoint(x: 0.04, y: 0.06)

    var body: some View {
        ZStack {
        Group {
            if model.creatingWorld {
                WorldBuilderCanvas(
                    model: model,
                    mode: "create",
                    worldName: "未命名世界",
                    canEdit: true,
                    onExit: {
                        iris.run(from: returnOrigin) { model.creatingWorld = false }
                    }
                )
                .ignoresSafeArea()
            } else if model.destination == .discover {
                DiscoverView(model: model) {
                    iris.run(from: createOrigin) { model.beginWorldCreation() }
                }
                .transition(.opacity)
            } else if model.destination == .profile {
                ProfileView(model: model)
                    .transition(.opacity)
            } else if model.destination == .worlds {
                // 世界集合属于账号层级；选中具体企划后，才进入带企划菜单的工作区。
                WorldsHomeView(model: model)
                    .transition(.opacity)
            } else {
                projectShell
                    .transition(
                        .opacity.combined(
                            with: .scale(scale: 1.012, anchor: .center)
                        )
                    )
            }
        }
        .overlay(alignment: .bottomLeading) {
            if !model.creatingWorld &&
                (model.destination == .discover ||
                 model.destination == .profile ||
                 model.destination == .worlds) {
                Group {
                    if model.destination == .discover {
                        ProfileAvatarDock(model: model)
                    } else {
                        ProfileBrandDock(model: model)
                    }
                }
                .padding(.leading, 24)
                .padding(.bottom, 24)
            }
        }
        .animation(.easeInOut(duration: 0.42), value: model.destination)
        .onChange(of: model.destination) { _, destination in
            guard !model.canAccess(destination) else { return }
            model.navigate(to: destination)
        }

            IrisCurtain(iris: iris)
        }
        .sheet(item: $model.activeSheet) { sheet in
            sheetView(sheet)
        }
    }

    private var projectShell: some View {
        ZStack {
            destinationView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AtlasCanvasBackground())
                .zIndex(0)
                .overlay(alignment: .top) {
                    if let toast = model.toast {
                        ToastView(message: toast)
                            .padding(.top, AtlasSpacing.l)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .animation(.snappy(duration: 0.24), value: model.toast)
        }
        .overlay(alignment: .bottomLeading) {
            ProfileBrandDock(model: model)
                .padding(.leading, 24)
                .padding(.bottom, 24)
        }
        .overlay(alignment: .bottomTrailing) {
            ProjectQuickMenu(model: model)
                .padding(.bottom, 24)
                .padding(.trailing, 12)
        }
    }

    @ViewBuilder
    private var destinationView: some View {
        switch model.destination {
        case .discover:
            EmptyView()
        case .profile:
            EmptyView()
        case .worlds:
            EmptyView()
        case .overview:
            PublicProjectView(model: model)
        case .canvas:
            WorldBuilderCanvas(
                model: model,
                mode: "manage",
                worldName: model.activeWorld.name,
                canEdit: model.activeRole == .owner && model.canWriteActiveWorld,
                onExit: { model.destination = .publicPreview }
            )
            .ignoresSafeArea()
            .id(model.activeWorldID)
        case .wiki:
            WorldWikiView(model: model)
        case .assets:
            AssetLibraryView(model: model)
        case .tasks:
            ParticipationHubView(model: model)
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
        case .characterCard:
            CharacterCardSheet(model: model)
        case .interactionInvite:
            InteractionInviteSheet(model: model)
        case .publicPageEditor:
            PublicPageEditorSheet(model: model)
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
