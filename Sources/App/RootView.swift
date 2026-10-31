import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct RootView: View {
    @State private var pickerItem: PhotosPickerItem?
    @State private var showFileImporter = false
    @State private var document: RedactDocument?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 26) {
                Spacer()
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(.tint)
                VStack(spacing: 6) {
                    Text("Redacto").font(.system(size: 38, weight: .bold))
                    Text("图片隐私打码 · 全程离线")
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 14) {
                    Label("离线", systemImage: "wifi.slash")
                    Label("无 SDK", systemImage: "checkmark.shield")
                    Label("去 EXIF", systemImage: "location.slash")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                Spacer()
                VStack(spacing: 0) {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        rowLabel("photo.on.rectangle", "从相册选择")
                    }
                    Divider().padding(.leading, 52)
                    Button { showFileImporter = true } label: {
                        rowLabel("folder", "从文件导入")
                    }
                    Divider().padding(.leading, 52)
                    Button { pasteFromClipboard() } label: {
                        rowLabel("doc.on.clipboard", "从剪贴板粘贴")
                    }
                    Divider().padding(.leading, 52)
                    Button {
                        document = RedactDocument(image: SampleImageGenerator.make())
                    } label: {
                        rowLabel("sparkles", "示例图片")
                    }
                }
                .buttonStyle(.plain)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 24)
                .padding(.bottom, 44)
            }
            .toolbar(.hidden, for: .navigationBar)
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.image]) { result in
                handleFileImport(result)
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                pickerItem = nil
                Task { await loadPickerItem(item) }
            }
            .fullScreenCover(item: $document) { doc in
                EditorView(document: doc)
            }
            .alert(
                "打开失败",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func rowLabel(_ symbol: String, _ title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .frame(width: 24)
                .foregroundStyle(.tint)
            Text(title)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    // MARK: - 导入

    private func loadPickerItem(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            errorMessage = "无法读取所选照片"
            return
        }
        document = RedactDocument(image: image)
    }

    private func handleFileImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let image = UIImage(contentsOfFile: url.path) else {
            errorMessage = "无法读取该图片文件"
            return
        }
        document = RedactDocument(image: image, fileURL: url)
    }

    private func pasteFromClipboard() {
        guard UIPasteboard.general.hasImages, let image = UIPasteboard.general.image else {
            errorMessage = "剪贴板里没有图片"
            return
        }
        document = RedactDocument(image: image)
    }
}
