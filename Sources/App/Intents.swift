import AppIntents
import Photos
import UIKit

/// App 快捷指令：抓取相册最新一张照片，落地 asset id 后拉起主 App，
/// 由 RootView 在 didBecomeActive 时接管并直接进编辑器。
struct RedactLatestPhotoIntent: AppIntent {
    static let pendingAssetKey = "pending_redact_asset"

    static var title: LocalizedStringResource = "打码最新的图片"
    static var description = IntentDescription("打开 Redacto 并载入相册中最新的一张照片")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else { return .result() }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 1
        guard let asset = PHAsset.fetchAssets(with: .image, options: options).firstObject else {
            return .result()
        }
        UserDefaults.standard.set(asset.localIdentifier, forKey: Self.pendingAssetKey)
        return .result()
    }
}

struct RedactoShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RedactLatestPhotoIntent(),
            phrases: [
                "用\(.applicationName)打码最新图片",
                "在\(.applicationName)里打码最新照片",
                "\(.applicationName)最新图片",
            ],
            shortTitle: "打码最新的图片",
            systemImageName: "eye.slash"
        )
    }
}
