import SwiftUI
import UIKit

struct ExportView: View {
    let document: RedactDocument
    @Environment(\.dismiss) private var dismiss

    enum ExportFormat: String, CaseIterable, Identifiable {
        case jpeg = "JPEG"
        case png = "PNG"
        var id: String { rawValue }

        var fileExtension: String { rawValue.lowercased() }
    }

    @State private var format: ExportFormat = .jpeg
    @State private var renderedImage: UIImage?
    @State private var renderError: String?
    @State private var savedToPhotos = false
    @State private var shareURL: URL?

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
                        prepareShare()
                    } label: {
                        Text("分享…")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .disabled(renderedImage == nil)
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
                ActivityView(items: [item.url])
            }
            .task { await render() }
            .onChange(of: format) { _ in
                Task { await render() }
            }
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
        let data = format == .png ? ImageCoder.pngData(image) : ImageCoder.jpegData(image)
        guard let data else {
            renderError = "编码失败"
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("redacto-\(Int(Date().timeIntervalSince1970)).\(format.fileExtension)")
        do {
            try data.write(to: url)
            shareURL = url
        } catch {
            renderError = "写入临时文件失败：\(error.localizedDescription)"
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
