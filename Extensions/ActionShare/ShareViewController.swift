import Photos
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// 分享面板扩展：接收图片，存入相册，再由用户从隐图里打码。
/// 全程离线，无网络，无第三方依赖。
final class ShareViewController: UIViewController {
    private let statusLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let icon = UIImageView(image: UIImage(systemName: "eye.slash.fill"))
        icon.tintColor = .systemPurple
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.text = "正在保存分享的图片…"
        statusLabel.font = .preferredFont(forTextStyle: .callout)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        spinner.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(icon)
        view.addSubview(statusLabel)
        view.addSubview(spinner)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -50),
            icon.widthAnchor.constraint(equalToConstant: 44),
            icon.heightAnchor.constraint(equalToConstant: 44),

            statusLabel.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 16),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        spinner.startAnimating()
        Task {
            await saveIncomingImages()
        }
    }

    private func saveIncomingImages() async {
        let attachments = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }
            .filter { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }

        guard !attachments.isEmpty else {
            statusLabel.text = "没有可处理的图片"
            spinner.stopAnimating()
            finish(after: 1.2)
            return
        }

        var savedCount = 0
        for attachment in attachments.prefix(10) {
            if await saveOne(attachment) {
                savedCount += 1
            }
        }

        spinner.stopAnimating()
        if savedCount > 0 {
            statusLabel.text = "已保存 \(savedCount) 张到相册，回隐图打码吧"
        } else {
            statusLabel.text = "保存失败（相册权限被拒绝）"
        }
        finish(after: 1.6)
    }

    private func saveOne(_ attachment: NSItemProvider) async -> Bool {
        guard let data = await loadData(from: attachment),
              let image = UIImage(data: data) else { return false }
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                guard status == .authorized || status == .limited else {
                    continuation.resume(returning: false)
                    return
                }
                PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                } completionHandler: { success, _ in
                    continuation.resume(returning: success)
                }
            }
        }
    }

    private func loadData(from attachment: NSItemProvider) async -> Data? {
        await withCheckedContinuation { continuation in
            _ = attachment.loadFileRepresentation(
                forTypeIdentifier: UTType.image.identifier
            ) { url, _ in
                guard let url, let data = try? Data(contentsOf: url) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: data)
            }
        }
    }

    private func finish(after delay: TimeInterval) {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
    }
}
