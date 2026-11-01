import SwiftUI

struct EditorView: View {
    let document: RedactDocument
    /// 照片编辑扩展内嵌模式：系统 Photos 已提供完成/取消，隐藏自带顶栏
    var chromeless = false
    @StateObject private var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showExport = false

    init(document: RedactDocument, chromeless: Bool = false) {
        self.document = document
        self.chromeless = chromeless
        _viewModel = StateObject(wrappedValue: EditorViewModel(document: document))
    }

    var body: some View {
        if chromeless {
            editorBody
        } else {
#if YINTU_EXTENSION
            // 扩展 target 不含 Export/，导出入口只存在于主 App
            editorBody
#else
            editorBody
                .sheet(isPresented: $showExport) {
                    ExportView(document: document) {
                        dismiss()
                    }
                }
#endif
        }
    }

    private var editorBody: some View {
        VStack(spacing: 0) {
            if !chromeless {
                topBar
            }
            canvas
            ToolPanel(viewModel: viewModel)
        }
        .background(Color(.systemBackground))
        .statusBarHidden()
        .onChange(of: document.blocks) { _, _ in
            viewModel.renderPreview()
        }
        .task {
            // 长按挑词需要词级框：打开时跑一次检测（有缓存，wand 不会重复跑 OCR）
            await viewModel.analyzeIfNeededForUI()
            if autoMaskOnOpen {
                await viewModel.runAutoRedact()
            }
        }
    }

    @AppStorage("auto_mask_on_open") private var autoMaskOnOpen = true

    // MARK: - 顶栏

    private var topBar: some View {
        HStack(spacing: 4) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 44, height: 44)
            }
            Spacer()
            Button {
                viewModel.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .frame(width: 44, height: 44)
            }
            .disabled(!viewModel.document.canUndo)
            Button {
                viewModel.redo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
                    .frame(width: 44, height: 44)
            }
            .disabled(!viewModel.document.canRedo)
            Button {
                viewModel.deleteSelected()
            } label: {
                Image(systemName: "trash")
                    .frame(width: 44, height: 44)
            }
            .disabled(viewModel.selectedBlockID == nil)
            Button {
                Task { await viewModel.runAutoRedact() }
            } label: {
                Image(systemName: "wand.and.stars")
                    .frame(width: 44, height: 44)
            }
            .disabled(viewModel.detecting)
            Button {
                showExport = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .frame(width: 44, height: 44)
            }
        }
        .font(.system(size: 17, weight: .medium))
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .padding(.horizontal, 6)
    }

    // MARK: - 画布

    private var canvas: some View {
        GeometryReader { geometry in
            let fit = fittedSize(in: geometry.size)
            ZStack {
                if let preview = viewModel.preview {
                    Image(uiImage: preview)
                        .resizable()
                        .interpolation(.medium)
                        .frame(width: fit.width, height: fit.height)
                    dragPreview(in: fit)
                    selectionBorder(in: fit)
                    brushPreview(in: fit)
                } else {
                    ProgressView()
                }
                CanvasGestureView(
                    zoomProvider: { viewModel.zoom },
                    onTap: { viewModel.tap(at: $0) },
                    onTwoFingerTap: { viewModel.resetZoom() },
                    onLongPress: { viewModel.longPress(at: $0) },
                    onDrawChanged: { viewModel.drawChanged(at: $0) },
                    onDrawEnded: { viewModel.drawEnded(at: $0) },
                    onDrawCancelled: { viewModel.drawCancelled() },
                    onPinch: { start, scale, translation, centroid in
                        viewModel.pinch(start: start, scale: scale,
                                        translation: translation, centroid: centroid)
                    },
                    onPinchEnded: {},
                    onTwoFingerPan: { start, translation in
                        viewModel.twoFingerPan(start: start, translation: translation)
                    },
                    onTwoFingerPanEnded: {}
                )
                .frame(width: fit.width, height: fit.height)
            }
            .scaleEffect(viewModel.zoom.scale, anchor: .topLeading)
            .offset(viewModel.zoom.offset)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .overlay(alignment: .bottom) {
                if viewModel.document.blocks.isEmpty {
                    Text("拖拽框选区域 · 双指缩放 · 点选遮盖块")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(.thinMaterial, in: Capsule())
                        .padding(.bottom, 10)
                }
            }
            .overlay {
                if viewModel.detecting {
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("正在检测敏感信息…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .onAppear { viewModel.fittedSize = fit }
            .onChange(of: geometry.size) { _, _ in
                viewModel.fittedSize = fittedSize(in: geometry.size)
            }
        }
    }

    private func fittedSize(in container: CGSize) -> CGSize {
        let imageSize = viewModel.document.imageSize
        guard imageSize.width > 0, imageSize.height > 0, container.width > 0 else { return .zero }
        let ratio = min(container.width / imageSize.width, container.height / imageSize.height)
        return CGSize(width: imageSize.width * ratio, height: imageSize.height * ratio)
    }

    /// 正在拖拽的框（虚线预览）
    @ViewBuilder
    private func dragPreview(in fit: CGSize) -> some View {
        if let rect = viewModel.dragRect {
            let frame = CGRect(
                x: rect.minX * fit.width,
                y: rect.minY * fit.height,
                width: rect.width * fit.width,
                height: rect.height * fit.height
            )
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                .background(Color.white.opacity(0.08))
                .frame(width: frame.width, height: frame.height)
                .offset(x: frame.midX - fit.width / 2, y: frame.midY - fit.height / 2)
        }
    }

    /// 选中块的描边
    @ViewBuilder
    private func selectionBorder(in fit: CGSize) -> some View {        if let block = viewModel.selectedBlock {
            let frame = CGRect(
                x: block.rect.minX * fit.width,
                y: block.rect.minY * fit.height,
                width: block.rect.width * fit.width,
                height: block.rect.height * fit.height
            )
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.accentColor, lineWidth: 2)
                .frame(width: frame.width, height: frame.height)
                .offset(x: frame.midX - fit.width / 2, y: frame.midY - fit.height / 2)
        }
    }

    /// 刷子正在画时的笔迹预览（圆点连线）
    @ViewBuilder
    private func brushPreview(in fit: CGSize) -> some View {
        if viewModel.activeTool == .brush, viewModel.strokePoints.count > 1 {
            let points = viewModel.strokePoints.map { CGPoint(x: $0.x * fit.width, y: $0.y * fit.height) }
            Path { path in
                path.move(to: points[0])
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
            }
            .stroke(
                viewModel.strokeColor.swiftUIColor.opacity(viewModel.opacity),
                style: StrokeStyle(
                    lineWidth: max(viewModel.pixelSize * fit.width, 4),
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
    }
}
