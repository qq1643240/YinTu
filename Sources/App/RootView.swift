import Photos
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct RootView: View {
    @State private var pickerItem: PhotosPickerItem?
    @State private var showFileImporter = false
    @State private var document: RedactDocument?
    @State private var errorMessage: String?
    @State private var showSettings = false
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "onboarding_done")
    @State private var loadingPendingPhoto = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 26) {
                Spacer()
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(.tint)
                VStack(spacing: 6) {
                    Text("Redacto").font(.system(size: 38, weight: .bold))
                    Text(L("root.subtitle"))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 14) {
                    Label(L("root.badge.offline"), systemImage: "wifi.slash")
                    Label(L("root.badge.no_sdk"), systemImage: "checkmark.shield")
                    Label(L("root.badge.exif"), systemImage: "location.slash")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                Spacer()
                VStack(spacing: 0) {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        rowLabel("photo.on.rectangle", L("root.pick.photos"))
                    }
                    Divider().padding(.leading, 52)
                    Button { showFileImporter = true } label: {
                        rowLabel("folder", L("root.pick.files"))
                    }
                    Divider().padding(.leading, 52)
                    Button { pasteFromClipboard() } label: {
                        rowLabel("doc.on.clipboard", L("root.pick.clipboard"))
                    }
                    Divider().padding(.leading, 52)
                    Button {
                        document = RedactDocument(image: SampleImageGenerator.make())
                    } label: {
                        rowLabel("sparkles", L("root.pick.sample"))
                    }
                }
                .buttonStyle(.plain)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 24)
                .padding(.bottom, 44)
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 17, weight: .medium))
                        .padding(10)
                        .background(.thinMaterial, in: Circle())
                }
                .padding(.trailing, 20)
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
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                checkPendingIntentPhoto()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView {
                    UserDefaults.standard.set(true, forKey: "onboarding_done")
                    showOnboarding = false
                }
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
        // itemIdentifier 即 PHAsset localIdentifier，供"分享并删除原图"使用
        document = RedactDocument(image: image, libraryAssetID: item.itemIdentifier)
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

    // MARK: - Spotlight 快捷指令（"打码最新的图片"）

    private func checkPendingIntentPhoto() {
        guard document == nil, !loadingPendingPhoto else { return }
        guard UserDefaults.standard.object(forKey: RedactLatestPhotoIntent.pendingAssetKey) != nil else { return }
        loadingPendingPhoto = true
        Task { await loadPendingIntentPhoto() }
    }

    private func loadPendingIntentPhoto() async {
        defer { loadingPendingPhoto = false }
        guard let assetID = UserDefaults.standard.string(forKey: RedactLatestPhotoIntent.pendingAssetKey) else { return }
        UserDefaults.standard.removeObject(forKey: RedactLatestPhotoIntent.pendingAssetKey)
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil).firstObject else {
            errorMessage = L("root.error.pending_missing")
            return
        }
        let data: Data? = await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isSynchronous = true
            options.isNetworkAccessAllowed = false
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                continuation.resume(returning: data)
            }
        }
        guard let data, let image = UIImage(data: data) else {
            errorMessage = L("root.error.pending_read")
            return
        }
        document = RedactDocument(image: image, libraryAssetID: assetID)
    }
}
