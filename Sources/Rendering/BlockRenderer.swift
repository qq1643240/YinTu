import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// 把遮盖块渲染到图像上。
/// 预览与导出共用同一管线，只是输入分辨率不同；
/// 块参数里的尺寸都按「图像宽度的比例」存储，因此两种分辨率下结果一致。
enum BlockRenderer {
    static let context = CIContext(options: [.cacheIntermediates: false])

    static func render(base: UIImage, blocks: [MaskBlock]) -> UIImage? {
        guard let cg = base.cgImage else { return nil }
        let original = CIImage(cgImage: cg)
        var output = original
        for block in blocks {
            output = apply(block, to: output, extent: original.extent, imageWidth: CGFloat(cg.width))
        }
        guard let result = context.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: result, scale: 1, orientation: .up)
    }

    // MARK: - 单块

    private static func apply(
        _ block: MaskBlock,
        to base: CIImage,
        extent: CGRect,
        imageWidth: CGFloat
    ) -> CIImage {
        let rect = pixelRect(for: block.rect, imageSize: extent.size)
        let effect = effectImage(for: block, base: base, extent: extent, imageWidth: imageWidth)
        let mask = maskImage(rect: rect, cornerRadius: block.cornerRadius, extent: extent)
        return effect.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: base,
            kCIInputMaskImageKey: mask,
        ])
    }

    /// 左上原点归一化 → CI 左下原点像素矩形
    private static func pixelRect(for normalized: CGRect, imageSize: CGSize) -> CGRect {
        CGRect(
            x: normalized.minX * imageSize.width,
            y: (1 - normalized.maxY) * imageSize.height,
            width: normalized.width * imageSize.width,
            height: normalized.height * imageSize.height
        )
    }

    private static func effectImage(
        for block: MaskBlock,
        base: CIImage,
        extent: CGRect,
        imageWidth: CGFloat
    ) -> CIImage {
        switch block.kind {
        case .colorBlock, .marker:
            let color = CIColor(
                red: block.color.red,
                green: block.color.green,
                blue: block.color.blue,
                alpha: block.opacity
            )
            return CIImage(color: color).cropped(to: extent)
        case .pixelate:
            let scale = max(block.pixelSize * imageWidth, 2)
            return base
                .applyingFilter("CIPixellate", parameters: [
                    kCIInputScaleKey: scale,
                    kCIInputCenterKey: CIVector(x: extent.midX, y: extent.midY),
                ])
                .cropped(to: extent)
        case .blur:
            let radius = max(block.blurRadius * imageWidth, 1)
            return base
                .clampedToExtent()
                .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius])
                .cropped(to: extent)
        }
    }

    /// 全幅黑底 + 白色圆角矩形（圆角之外的区域透出背景）
    private static func maskImage(rect: CGRect, cornerRadius: Double, extent: CGRect) -> CIImage {
        let black = CIImage(color: CIColor.black).cropped(to: extent)
        let generator = CIFilter.roundedRectangleGenerator()
        generator.width = Float(rect.width)
        generator.height = Float(rect.height)
        generator.radius = Float(min(rect.width, rect.height) * 2 * cornerRadius)
        generator.color = CIColor.white
        guard let white = generator.outputImage else { return black }
        let centered = white.transformed(by: CGAffineTransform(
            translationX: rect.midX,
            y: rect.midY
        ))
        return centered.composited(over: black)
    }
}
