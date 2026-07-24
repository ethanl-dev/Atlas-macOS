import SwiftUI

struct RootView: View {
    @StateObject private var model = AtlasAppModel()
    @State private var isCreatingWorld = false

    var body: some View {
        Group {
            if model.destination == .discover {
                if isCreatingWorld {
                    WorldCreationFlow(model: model) {
                        withAnimation(.snappy(duration: 0.32)) {
                            isCreatingWorld = false
                        }
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    DiscoverView(model: model) {
                        withAnimation(.snappy(duration: 0.32)) {
                            isCreatingWorld = true
                        }
                    }
                    .transition(.opacity)
                }
            } else {
                projectShell
            }
        }
        .animation(.snappy(duration: 0.32), value: isCreatingWorld)
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
            WorldCanvasView(model: model)
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
            WorldCreationFlow(model: model)
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
