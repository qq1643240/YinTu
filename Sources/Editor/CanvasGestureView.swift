import SwiftUI
import UIKit

/// 当前视图缩放状态。scale 恒 ≥ 1。
struct CanvasZoom: Equatable {
    var scale: CGFloat = 1
    var offset: CGSize = .zero

    static let identity = CanvasZoom()
}

/// 手势宿主：把 UIKit 识别器桥成归一化坐标回调。
/// 单指拖拽=框选，双指捏合=缩放，双指拖动=平移（仅放大后），双指轻点=复位，单击=选中。
struct CanvasGestureView: UIViewRepresentable {
    var zoomProvider: () -> CanvasZoom
    var onTap: (CGPoint) -> Void
    var onTwoFingerTap: () -> Void
    var onDrawChanged: (CGPoint) -> Void
    var onDrawEnded: (CGPoint) -> Void
    var onDrawCancelled: () -> Void
    var onPinch: (CanvasZoom, CGFloat, CGPoint, CGPoint) -> Void
    var onPinchEnded: () -> Void
    var onTwoFingerPan: (CanvasZoom, CGPoint) -> Void
    var onTwoFingerPanEnded: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        let twoFingerTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTwoFingerTap(_:))
        )
        twoFingerTap.numberOfTouchesRequired = 2

        let draw = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDraw(_:))
        )
        draw.minimumNumberOfTouches = 1
        draw.maximumNumberOfTouches = 1

        let pinch = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        )
        let twoFingerPan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTwoFingerPan(_:))
        )
        twoFingerPan.minimumNumberOfTouches = 2
        twoFingerPan.maximumNumberOfTouches = 2
        // 纯双指拖动等捏合失败后再生效，避免缩放+平移同时叠加
        twoFingerPan.require(toFail: pinch)

        for recognizer in [tap, twoFingerTap, draw, pinch, twoFingerPan] {
            view.addGestureRecognizer(recognizer)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject {
        var parent: CanvasGestureView
        var pinchStart = CanvasZoom.identity
        var panStart = CanvasZoom.identity

        init(_ parent: CanvasGestureView) {
            self.parent = parent
        }

        func normalizedPoint(_ gesture: UIGestureRecognizer) -> CGPoint {
            guard let view = gesture.view, view.bounds.width > 0, view.bounds.height > 0 else {
                return .zero
            }
            let p = gesture.location(in: view)
            return CGPoint(x: p.x / view.bounds.width, y: p.y / view.bounds.height)
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended else { return }
            parent.onTap(normalizedPoint(gesture))
        }

        @objc func handleTwoFingerTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended else { return }
            parent.onTwoFingerTap()
        }

        @objc func handleDraw(_ gesture: UIPanGestureRecognizer) {
            switch gesture.state {
            case .changed:
                parent.onDrawChanged(normalizedPoint(gesture))
            case .ended:
                parent.onDrawEnded(normalizedPoint(gesture))
            case .failed, .cancelled:
                // 第二根手指落下等情况：识别器到不了 .ended，直接丢弃本次拖拽
                parent.onDrawCancelled()
            default:
                break
            }
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            switch gesture.state {
            case .began:
                pinchStart = parent.zoomProvider()
            case .changed:
                let translation = gesture.translation(in: gesture.view)
                let centroid = gesture.location(in: gesture.view)
                parent.onPinch(pinchStart, gesture.scale, translation, centroid)
            case .ended:
                parent.onPinchEnded()
            default:
                break
            }
        }

        @objc func handleTwoFingerPan(_ gesture: UIPanGestureRecognizer) {
            switch gesture.state {
            case .began:
                panStart = parent.zoomProvider()
            case .changed:
                let translation = gesture.translation(in: gesture.view)
                parent.onTwoFingerPan(panStart, translation)
            case .ended:
                parent.onTwoFingerPanEnded()
            default:
                break
            }
        }
    }
}
