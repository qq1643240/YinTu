import SwiftUI

struct EditorView: View {
    let document: RedactDocument
    @StateObject private var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showExport = false

    init(document: RedactDocument) {
        self.document = document
        _viewModel = StateObject(wrappedValue: EditorViewModel(document: document))
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            canvas
            ToolPanel(viewModel: viewModel)
        }
        .background(Color(.systemBackground))
        .statusBarHidden()
        .sheet(isPresented: $showExport) {
            ExportView(document: document)
        }
        .onChange(of: document.blocks) { _ in
            viewModel.renderPreview()
        }
    }

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
                        .interpolation(.none)
                        .frame(width: fit.width, height: fit.height)
                    dragPreview(in: fit)
                    selectionBorder(in: fit)
                } else {
                    ProgressView()
                }
                CanvasGestureView(
                    zoomProvider: { viewModel.zoom },
                    onTap: { viewModel.tap(at: $0) },
                    onTwoFingerTap: { viewModel.resetZoom() },
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
            .onAppear { viewModel.fittedSize = fit }
            .onChange(of: geometry.size) { _ in
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
    private func selectionBorder(in fit: CGSize) -> some View {
        if let block = viewModel.selectedBlock {
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
}
