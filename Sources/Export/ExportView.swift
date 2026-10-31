import Photos
import SwiftUI
import UIKit

struct ExportView: View {
    let document: RedactDocument
    /// 删除原图成功后回调（关闭编辑器）
    var onOriginalDeleted: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    enum ExportFormat: String, CaseIterable, Identifiable {
        case jpeg = "JPEG"
        case png = "PNG"
        var id: String { rawValue }

        var fileExtension: String { rawValue.lowercased() }
    }

    @State private var format: ExportFormat = .jpeg
    @State private var quality: Double = 0.92
    @State private var renderedImage: UIImage?
    @State private var renderError: String?
    @State private var savedToPhotos = false
    @State private var shareURL: URL?
    @State private var deleteAfterShare = false

    private var canDeleteOriginal: Bool {
        document.libraryAssetID != nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let image = renderedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else if let error = renderError {
                    Text(error).foregroundStyle(.red)
                } else {
                    ProgressView("正在全分辨率渲染…")
                        .padding(.vertical, 60)
                }
                Picker("格式", selection: $format) {
                    ForEach(ExportFormat.allCases) { $0 }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                if format == .jpeg {
                    HStack(spacing: 10) {
                        Text("质量").font(.caption).foregroundStyle(.secondary)
                        Slider(value: $quality, in: 0.5...1)
                        Text("\(Int(quality * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 40)
                    }
                    .padding(.horizontal)
                }
                Spacer()
                VStack(spacing: 12) {
                    Button {
                        saveToPhotos()
                    } label: {
                        Text("保存到相册")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(renderedImage == nil)

                    Button {
                        deleteAfterShare = false
                        prepareShare()
                    } label: {
                        Text("分享…")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .disabled(renderedImage == nil)

                    if canDeleteOriginal {
                        Button {
                            deleteAfterShare = true
                            prepareShare()
                        } label: {
                            Text("分享并删除原图…")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .disabled(renderedImage == nil)
                    }
                }
                .padding(.horizontal)
                if savedToPhotos {
                    Text("已保存").font(.caption).foregroundStyle(.green)
                }
            }
            .padding(.top, 8)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text("导出").fontWeight(.semibold)
                        Text("\(Int(document.imageSize.width)) × \(Int(document.imageSize.height)) · EXIF 已剥离")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(item: Binding(
                get: { shareURL.map(ShareItem.init) },
                set: { shareURL = $0?.url }
            )) { item in
                ActivityView(items: [item.url]) { completed in
                    handleShareCompleted(completed)
                }
            }
            .task { await render() }
        }
    }

    private struct ShareItem: Identifiable {
        let url: URL
        var id: String { url.absoluteString }
    }

    private func render() async {
        renderError = nil
        let base = document.source
        let blocks = document.blocks
        let image = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            BlockRenderer.render(base: base, blocks: blocks)
        }.value
        if let image {
            renderedImage = image
        } else {
            renderError = "渲染失败，请重试"
        }
    }

    private func saveToPhotos() {
        guard let image = renderedImage else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        savedToPhotos = true
    }

    private func prepareShare() {
        guard let image = renderedImage else { return }
        let data: Data?
        switch format {
        case .png:
            data = ImageCoder.pngData(image)
        case .jpeg:
            data = ImageCoder.jpegData(image, quality: quality)
        }
        guard let data else {
            renderError = "编码失败"
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("yintu-\(Int(Date().timeIntervalSince1970)).\(format.fileExtension)")
        do {
            try data.write(to: url)
            shareURL = url
        } catch {
            renderError = "写入临时文件失败：\(error.localizedDescription)"
        }
    }

    private func handleShareCompleted(_ completed: Bool) {
        guard completed, deleteAfterShare, let assetID = document.libraryAssetID else { return }
        Task {
            let deleted = await OriginalPhotoDeleter.delete(assetID: assetID)
            if deleted {
                onOriginalDeleted?()
            } else {
                renderError = "删除原图失败（可能没有相册权限）"
            }
            deleteAfterShare = false
        }
    }
}

/// "分享并删除原图"：从相册删除选中的 PHAsset（系统会弹确认）。
enum OriginalPhotoDeleter {
    static func delete(assetID: String) async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else { return false }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
        guard assets.count > 0 else { return false }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets)
            }
            return true
        } catch {
            return false
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    var onComplete: ((Bool) -> Void)?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            onComplete?(completed)
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
