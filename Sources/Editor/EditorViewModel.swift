import Combine
import SwiftUI
import UIKit

/// 编辑器状态机。
/// 预览渲染带 50ms 防抖：滑杆连续拖动时不会每次 tick 都重跑 CoreImage。
@MainActor
final class EditorViewModel: ObservableObject {
    let document: RedactDocument

    @Published var activeTool: ToolKind = .colorBlock
    @Published var strokeColor: RGBA = .ink
    @Published var pixelSize: Double = 0.03
    @Published var blurRadius: Double = 0.02
    @Published var opacity: Double = 1
    @Published var cornerRadius: Double = 0
    @Published var selectedBlockID: UUID?
    @Published var dragStart: CGPoint?
    @Published var dragRect: CGRect?
    @Published var zoom = CanvasZoom.identity
    @Published var preview: UIImage?
    @Published var fittedSize: CGSize = .zero
    @Published var detecting = false

    var selectedBlock: MaskBlock? {
        guard let id = selectedBlockID else { return nil }
        return document.blocks.first { $0.id == id }
    }

    private var cancellables = Set<AnyCancellable>()
    private var previewTask: Task<Void, Never>?

    init(document: RedactDocument) {
        self.document = document
        // 转发 document 的变更，否则 SwiftUI 观察不到 document.blocks 的修改
        document.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        renderNow()
    }

    deinit {
        previewTask?.cancel()
    }

    // MARK: - 工具

    func selectTool(_ tool: ToolKind) {
        activeTool = tool
        applyToolDefaults()
        selectedBlockID = nil
    }

    /// 切换工具时恢复默认笔刷参数；圆角是全局偏好，不重置
    private func applyToolDefaults() {
        switch activeTool {
        case .colorBlock:
            strokeColor = .ink
            opacity = 1
        case .marker:
            strokeColor = .markerYellow
            opacity = 0.45
        case .pixelate:
            pixelSize = max(pixelSize, 0.02)
        case .blur:
            blurRadius = max(blurRadius, 0.01)
        }
    }

    // MARK: - 手势回调（坐标均为归一化 0…1）

    func drawChanged(at point: CGPoint) {
        if dragStart == nil { dragStart = point }
        dragRect = Self.rectBetween(dragStart ?? point, point)
    }

    func drawEnded(at point: CGPoint) {
        defer {
            dragStart = nil
            dragRect = nil
        }
        guard let start = dragStart else { return }
        let rect = Self.rectBetween(start, point)
        guard rect.width > 0.008, rect.height > 0.008 else { return }
        var block = MaskBlock(kind: activeTool, rect: rect)
        block.color = strokeColor
        block.opacity = opacity
        block.pixelSize = pixelSize
        block.blurRadius = blurRadius
        block.cornerRadius = cornerRadius
        var newBlocks = document.blocks
        newBlocks.append(block)
        document.commit(newBlocks)
    }

    static func rectBetween(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        CGRect(
            x: min(a.x, b.x),
            y: min(a.y, b.y),
            width: abs(a.x - b.x),
            height: abs(a.y - b.y)
        )
    }

    /// 拖拽被打断（如第二根手指落下）：丢弃预览框，不产生块
    func drawCancelled() {
        dragStart = nil
        dragRect = nil
    }

    func tap(at point: CGPoint) {
        // 命中容差：块外扩 0.01 也算命中；再点已选中的块取消选中
        let hit = document.blocks.last { block in
            block.rect.insetBy(dx: -0.01, dy: -0.01).contains(point)
        }
        if let hit {
            selectedBlockID = (selectedBlockID == hit.id) ? nil : hit.id
        } else {
            selectedBlockID = nil
        }
    }

    // MARK: - 缩放/平移

    /// o = o0 + t − c·(s − s0)，c 为捏合中心（视图点坐标）
    func pinch(start: CanvasZoom, scale: CGFloat, translation: CGPoint, centroid: CGPoint) {
        let newScale = max(start.scale * scale, 1)
        let raw = CGSize(
            width: start.offset.width + translation.x - centroid.x * (newScale - start.scale),
            height: start.offset.height + translation.y - centroid.y * (newScale - start.scale)
        )
        zoom.scale = newScale
        zoom.offset = clampedOffset(raw, scale: newScale)
    }

    func twoFingerPan(start: CanvasZoom, translation: CGPoint) {
        guard start.scale > 1 else { return }
        zoom.scale = start.scale
        zoom.offset = clampedOffset(
            CGSize(width: start.offset.width + translation.x,
                   height: start.offset.height + translation.y),
            scale: start.scale
        )
    }

    func resetZoom() {
        zoom = .identity
    }

    private func clampedOffset(_ offset: CGSize, scale: CGFloat) -> CGSize {
        guard scale > 1, fittedSize.width > 0, fittedSize.height > 0 else { return .zero }
        let maxX = fittedSize.width * (scale - 1) / 2
        let maxY = fittedSize.height * (scale - 1) / 2
        return CGSize(
            width: max(-maxX, min(maxX, offset.width)),
            height: max(-maxY, min(maxY, offset.height))
        )
    }

    // MARK: - 自动打码（M3 检测引擎）

    /// 检测人脸/条码/电话/邮箱/证件号/车牌/卡号/姓名并直接打码。
    /// 预算：OCR 在 ≤2048px 降采样图上跑，归一化坐标保证全分辨率导出一致。
    func runAutoRedact() async {
        guard !detecting else { return }
        detecting = true
        defer { detecting = false }

        let base = ImageCoder.downscaled(document.source, maxDimension: 2048)
        guard let cgImage = base.cgImage else { return }
        let analysis = await Task.detached(priority: .userInitiated) { () -> VisionAnalysis in
            VisionAnalyzer.analyze(cgImage: cgImage)
        }.value

        let newBlocks = DetectionService.autoRedactBlocks(
            from: analysis.sensitive,
            existing: document.blocks
        )
        guard !newBlocks.isEmpty else { return }
        document.commit(document.blocks + newBlocks)
    }

    // MARK: - 历史与选中块

    func undo() {
        document.undo()
        selectedBlockID = nil
    }

    func redo() {
        document.redo()
        selectedBlockID = nil
    }

    func deleteSelected() {
        guard let id = selectedBlockID else { return }
        var newBlocks = document.blocks
        newBlocks.removeAll { $0.id == id }
        document.commit(newBlocks)
        selectedBlockID = nil
    }

    /// 选中块参数微调（不产生新撤销点）
    func modifySelected(_ mutate: (inout MaskBlock) -> Void) {
        guard var block = selectedBlock else { return }
        mutate(&block)
        document.updateLive(block)
    }

    // MARK: - 预览渲染

    func renderPreview() {
        previewTask?.cancel()
        previewTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 50_000_000)
            guard let self, !Task.isCancelled else { return }
            self.renderInternal()
        }
    }

    func renderNow() {
        previewTask?.cancel()
        renderInternal()
    }

    private func renderInternal() {
        let base = ImageCoder.downscaled(document.source, maxDimension: 1600)
        let blocks = document.blocks
        let task = Task.detached(priority: .userInitiated) { [weak self] in
            let image = BlockRenderer.render(base: base, blocks: blocks)
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                self?.preview = image
            }
        }
        previewTask = task
    }
}
