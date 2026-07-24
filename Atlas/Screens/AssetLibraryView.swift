import SwiftUI
import UniformTypeIdentifiers

struct AssetLibraryView: View {
    @ObservedObject var model: AtlasAppModel
    @State private var selectedCategory = "全部"
    @State private var selectedAssetID = "asset-1"
    @State private var importing = false

    private let categories = ["全部", "插画", "角色", "场景", "文档"]
    private let assets = AtlasAsset.samples

    private var filteredAssets: [AtlasAsset] {
        selectedCategory == "全部" ? assets : assets.filter { $0.category == selectedCategory }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(AtlasColor.borderSubtle)

            HSplitView {
                library
                    .frame(minWidth: 520)
                preview
                    .frame(minWidth: 280, idealWidth: 340, maxWidth: 420)
            }
        }
        .background(AtlasCanvasBackground())
        .fileImporter(
            isPresented: $importing,
            allowedContentTypes: [.image, .pdf, .plainText, .data],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                model.showToast("已选择 \(urls.count) 个文件，等待分类")
            case .failure:
                model.showToast("未能读取所选文件")
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
                Text("世界资产")
                    .font(AtlasFont.title)
                Text("设卡、视觉资料、文档和共创文件使用同一个引用系统")
                    .font(AtlasFont.body)
                    .foregroundStyle(AtlasColor.textSecondary)
            }
            Spacer()
            Button {
                model.showToast("已创建空白文本资产")
            } label: {
                AtlasButtonLabel(title: "新建文本", systemImage: "doc.badge.plus")
            }
            .buttonStyle(.atlas(.glass))

            Button {
                importing = true
            } label: {
                AtlasButtonLabel(title: "上传文件", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.atlas(.primary))
        }
        .padding(AtlasSpacing.xl)
    }

    private var library: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.l) {
            HStack(spacing: AtlasSpacing.xs) {
                ForEach(categories, id: \.self) { category in
                    Button {
                        withAnimation(.snappy) { selectedCategory = category }
                    } label: {
                        Text(category)
                            .font(AtlasFont.caption)
                            .foregroundStyle(selectedCategory == category ? AtlasColor.inverse : AtlasColor.textSecondary)
                            .padding(.horizontal, AtlasSpacing.m)
                            .padding(.vertical, 6)
                            .background {
                                if selectedCategory == category {
                                    Capsule().fill(Color.white)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Text("\(filteredAssets.count) 项")
                    .font(AtlasFont.monoSmall)
                    .foregroundStyle(AtlasColor.textTertiary)
            }

            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 170, maximum: 230), spacing: AtlasSpacing.m)],
                    spacing: AtlasSpacing.m
                ) {
                    ForEach(filteredAssets) { asset in
                        AssetTile(asset: asset, selected: selectedAssetID == asset.id) {
                            selectedAssetID = asset.id
                        }
                    }
                }
                .padding(.bottom, AtlasSpacing.xl)
            }
        }
        .padding(AtlasSpacing.xl)
    }

    private var preview: some View {
        let asset = assets.first(where: { $0.id == selectedAssetID }) ?? assets[0]

        return VStack(alignment: .leading, spacing: AtlasSpacing.l) {
            AssetArtwork(seed: asset.seed, symbol: asset.symbol)
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: AtlasRadius.card, style: .continuous))

            VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
                Text(asset.name)
                    .font(AtlasFont.title)
                Text(asset.category)
                    .font(AtlasFont.monoSmall)
                    .foregroundStyle(AtlasColor.textTertiary)
            }

            Divider().overlay(AtlasColor.borderSubtle)

            InspectorProperty(label: "文件类型", value: asset.fileType)
            InspectorProperty(label: "更新时间", value: "2 天前")
            InspectorProperty(label: "引用对象", value: "\(asset.references)")
            InspectorProperty(label: "可见范围", value: asset.visibility)

            Spacer()

            HStack {
                Button {
                    model.showToast("已定位到 \(asset.references) 个引用对象")
                } label: {
                    Image(systemName: "link")
                }
                .buttonStyle(.atlas(.glass))
                .help("查看引用")

                Button {
                    model.showToast("下载任务已建立")
                } label: {
                    Image(systemName: "arrow.down.to.line")
                }
                .buttonStyle(.atlas(.glass))
                .help("下载")

                if model.accessMode == .manage {
                    Spacer()
                    Button {
                        model.showToast("资产已移到归档区")
                    } label: {
                        Image(systemName: "archivebox")
                    }
                    .buttonStyle(.atlas(.ghost))
                    .help("归档")
                }
            }
        }
        .padding(AtlasSpacing.xl)
        .background(AtlasColor.canvas.opacity(0.50))
    }
}

private struct AtlasAsset: Identifiable {
    let id: String
    let name: String
    let category: String
    let fileType: String
    let references: Int
    let visibility: String
    let seed: Int
    let symbol: String

    static let samples: [AtlasAsset] = [
        .init(id: "asset-1", name: "雾港全景", category: "场景", fileType: "PNG", references: 6, visibility: "公开", seed: 1, symbol: "water.waves"),
        .init(id: "asset-2", name: "岑 · 角色立绘", category: "角色", fileType: "PSD", references: 9, visibility: "企划成员", seed: 2, symbol: "person.crop.rectangle"),
        .init(id: "asset-3", name: "白塔概念图", category: "插画", fileType: "PNG", references: 4, visibility: "公开", seed: 3, symbol: "building.columns"),
        .init(id: "asset-4", name: "夜航规则", category: "文档", fileType: "MD", references: 7, visibility: "企划成员", seed: 4, symbol: "doc.text"),
        .init(id: "asset-5", name: "潮汐航线", category: "场景", fileType: "PDF", references: 3, visibility: "管理者", seed: 5, symbol: "map"),
        .init(id: "asset-6", name: "信使服装参考", category: "角色", fileType: "JPG", references: 5, visibility: "企划成员", seed: 6, symbol: "tshirt")
    ]
}

private struct AssetTile: View {
    var asset: AtlasAsset
    var selected: Bool
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: AtlasSpacing.s) {
                AssetArtwork(seed: asset.seed, symbol: asset.symbol)
                    .frame(height: 128)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(asset.name)
                            .font(AtlasFont.label)
                            .lineLimit(1)
                        Text("\(asset.fileType) · \(asset.category)")
                            .font(AtlasFont.monoSmall)
                            .foregroundStyle(AtlasColor.textTertiary)
                    }
                    Spacer()
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                    }
                }
            }
            .foregroundStyle(AtlasColor.textPrimary)
            .padding(7)
            .background(Color.white.opacity(selected ? 0.08 : hovering ? 0.045 : 0.02), in: RoundedRectangle(cornerRadius: AtlasRadius.card))
            .overlay(RoundedRectangle(cornerRadius: AtlasRadius.card).stroke(selected ? AtlasColor.borderStrong : AtlasColor.borderSubtle))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

private struct AssetArtwork: View {
    var seed: Int
    var symbol: String

    var body: some View {
        ZStack {
            Color(white: 0.08 + Double(seed % 3) * 0.018)
            Canvas { context, size in
                for index in 0..<8 {
                    let inset = CGFloat(index * 14 + seed * 3)
                    let rect = CGRect(
                        x: -size.width * 0.16 + inset,
                        y: size.height * 0.08 + CGFloat(index % 3) * 11,
                        width: size.width * 1.22 - inset * 1.2,
                        height: size.height * 0.84 - inset * 0.45
                    )
                    var path = Path()
                    path.addRoundedRect(in: rect, cornerSize: CGSize(width: 80, height: 80))
                    context.stroke(path, with: .color(.white.opacity(0.045 + Double(index) * 0.012)), lineWidth: 1)
                }
            }
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .ultraLight))
                .foregroundStyle(Color.white.opacity(0.75))
        }
    }
}
