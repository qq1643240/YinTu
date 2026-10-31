import UIKit

/// 一张待打码的图片及其遮盖块列表。
/// 值语义的块数组 + 快照式历史栈，undo/redo 成本可忽略。
final class RedactDocument: ObservableObject, Identifiable {
    let id = UUID()
    /// 原图（已烘焙为朝上方向），只读
    let source: UIImage
    /// 来源文件；剪贴板/示例图为 nil
    let fileURL: URL?
    /// 相册资产的 localIdentifier（从相册选择时记录），用于"分享并删除原图"
    let libraryAssetID: String?

    @Published private(set) var blocks: [MaskBlock] = []
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false

    private var history: [[MaskBlock]] = [[]]
    private var historyIndex = 0

    init(image: UIImage, fileURL: URL? = nil, libraryAssetID: String? = nil, initialBlocks: [MaskBlock] = []) {
        self.source = ImageCoder.normalized(image)
        self.fileURL = fileURL
        self.libraryAssetID = libraryAssetID
        if !initialBlocks.isEmpty {
            blocks = initialBlocks
            history = [initialBlocks]
        }
    }

    var imageSize: CGSize { source.size }

    // MARK: - 编辑操作

    /// 结构性修改（新增/删除），压入一条撤销记录
    func commit(_ newBlocks: [MaskBlock]) {
        guard newBlocks != blocks else { return }
        history.removeSubrange((historyIndex + 1)...)
        history.append(newBlocks)
        historyIndex = history.count - 1
        blocks = newBlocks
        refreshFlags()
    }

    /// 参数微调（滑杆/取色过程中）：只改写当前历史记录，不产生新撤销点
    func updateLive(_ block: MaskBlock) {
        guard let index = blocks.firstIndex(where: { $0.id == block.id }) else { return }
        blocks[index] = block
        history[historyIndex] = blocks
    }

    func undo() {
        guard historyIndex > 0 else { return }
        historyIndex -= 1
        blocks = history[historyIndex]
        refreshFlags()
    }

    func redo() {
        guard historyIndex < history.count - 1 else { return }
        historyIndex += 1
        blocks = history[historyIndex]
        refreshFlags()
    }

    private func refreshFlags() {
        canUndo = historyIndex > 0
        canRedo = historyIndex < history.count - 1
    }
}
