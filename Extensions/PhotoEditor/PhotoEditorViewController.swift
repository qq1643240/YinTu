import Photos
import PhotosUI
import SwiftUI
import UIKit

/// Photos「编辑」扩展主体。
/// 首次编辑：从原图 + 空块开始；再次编辑：从 adjustmentData 还原块。
/// 完成时把渲染结果写入 renderedContentURL，并把块列表存回 adjustmentData。
final class PhotoEditorViewController: UIViewController, PHContentEditingController {
    private var contentEditingInput: PHContentEditingInput?
    private var document: RedactDocument?
    private var hostingController: UIHostingController<PhotoEditingRoot>?
    private var pendingRender: Task<Void, Never>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }

    // MARK: - PHContentEditingController

    func canHandle(_ adjustmentData: PHAdjustmentData) -> Bool {
        BlockArchive.isOurs(adjustmentData)
    }

    var shouldShowCancelConfirmation: Bool { true }

    func startContentEditing(with contentEditingInput: PHContentEditingInput, placeholderImage: UIImage) {
        self.contentEditingInput = contentEditingInput

        let restored: [MaskBlock]
        if let adjustment = contentEditingInput.adjustmentData, BlockArchive.isOurs(adjustment),
           let decoded = BlockArchive.decode(adjustment.data) {
            restored = decoded
        } else {
            restored = []
        }

        let displayImage = contentEditingInput.displaySizeImage ?? placeholderImage
        let document = RedactDocument(image: displayImage, initialBlocks: restored)
        self.document = document

        let root = PhotoEditingRoot(document: document)
        let host = UIHostingController(rootView: root)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(host)
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)
        hostingController = host
    }

    func finishContentEditing(completionHandler: @escaping (PHContentEditingOutput?) -> Void) {
        guard let input = contentEditingInput, let document = document else {
            completionHandler(nil)
            return
        }
        let blocks = document.blocks
        pendingRender = Task { [weak self] in
            guard let self else {
                completionHandler(nil)
                return
            }
            let output = await self.renderOutput(input: input, blocks: blocks)
            self.pendingRender = nil
            completionHandler(output)
        }
    }

    func cancelContentEditing() {
        pendingRender?.cancel()
        pendingRender = nil
        contentEditingInput = nil
        hostingController?.view.removeFromSuperview()
        hostingController = nil
    }

    // MARK: - 渲染输出

    private func renderOutput(input: PHContentEditingInput, blocks: [MaskBlock]) async -> PHContentEditingOutput? {
        guard let fullURL = input.fullSizeImageURL,
              let raw = UIImage(contentsOfFile: fullURL.path) else {
            return nil
        }
        let original = ImageCoder.normalized(raw)
        let output = PHContentEditingOutput(contentEditingInput: input)
        let rendered = await Task.detached(priority: .userInitiated) { () -> Data? in
            guard let image = BlockRenderer.render(base: original, blocks: blocks) else { return nil }
            return ImageCoder.jpegData(image)
        }.value
        guard let jpeg = rendered else { return nil }
        do {
            try jpeg.write(to: output.renderedContentURL, options: .atomic)
        } catch {
            return nil
        }
        output.adjustmentData = PHAdjustmentData(
            formatIdentifier: BlockArchive.formatIdentifier,
            formatVersion: BlockArchive.formatVersion,
            data: BlockArchive.encode(blocks) ?? Data()
        )
        return output
    }
}

/// 扩展内嵌的编辑器根视图（复用主 App 的完整编辑器）。
struct PhotoEditingRoot: View {
    @StateObject private var holder: DocumentHolder

    final class DocumentHolder: ObservableObject {
        let document: RedactDocument

        init(document: RedactDocument) {
            self.document = document
        }
    }

    init(document: RedactDocument) {
        _holder = StateObject(wrappedValue: DocumentHolder(document: document))
    }

    var body: some View {
        EditorView(document: holder.document, chromeless: true)
    }
}
