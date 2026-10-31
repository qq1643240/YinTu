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
        let effect = effectImage(for: block, base: base, extent: extent, imageWidth: imageWidth, rect: rect)
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
        imageWidth: CGFloat,
        rect: CGRect
    ) -> CIImage {
        switch block.kind {
        case .colorBlock, .marker, .brush, .hideText, .inkStroke:
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

        case .cityLights:
            let radius = max(block.blurRadius * imageWidth, 2)
            return base
                .clampedToExtent()
                .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius])
                .applyingFilter("CIBloom", parameters: [
                    kCIInputRadiusKey: radius * 0.8,
                    kCIInputIntensityKey: 0.9,
                ])
                .cropped(to: extent)

        case .noisyColorBlock:
            let gridSize = max(block.pixelSize * imageWidth, 2)
            return (CIFilter.randomGenerator().outputImage ?? CIImage.empty())
                .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
                .applyingFilter("CIPixellate", parameters: [
                    kCIInputScaleKey: gridSize,
                    kCIInputCenterKey: CIVector(x: extent.midX, y: extent.midY),
                ])
                .cropped(to: extent)

        case .rainbowBelt:
            return rainbowGradient
                .map { $0.rotatedDiagonal(extent: extent) } ?? CIImage(color: .magenta).cropped(to: extent)

        case .rainbowGrid:
            let gridSize = Float(max(block.pixelSize * imageWidth, 3))
            let checker = CIFilter.checkerboardGenerator()
            checker.width = gridSize
            checker.sharpness = 1
            checker.color1 = CIColor(red: 1, green: 0.3, blue: 0.6)
            checker.color0 = CIColor(red: 0.3, green: 0.8, blue: 1)
            return (checker.outputImage ?? CIImage.empty()).cropped(to: extent)

        case .emoji:
            return TextTiler.emojiTile(emoji: block.emoji, blockRect: rect, extent: extent)
                ?? CIImage(color: .black).cropped(to: extent)

        case .watermark:
            return TextTiler.watermarkTile(
                text: block.watermarkText,
                fontSize: max(block.watermarkSize * imageWidth, 8),
                angleDegrees: block.watermarkAngle,
                opacity: block.opacity,
                lineSpacing: block.watermarkLineSpacing,
                extent: extent
            ) ?? CIImage.empty().cropped(to: extent)
        }
    }

    /// 全幅黑底 + 白色圆角矩形（圆角之外的区域透出背景）
    /// 用 UIKit 画布绘制：CIRoundedRectangleGenerator 的类型化属性在 iOS 26 SDK 里名称不稳。
    private static func maskImage(rect: CGRect, cornerRadius: Double, extent: CGRect) -> CIImage {
        let black = CIImage(color: CIColor.black).cropped(to: extent)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let canvas = CGSize(width: ceil(extent.width), height: ceil(extent.height))
        // UIKit 画布 y 向下、CI 空间 y 向上：绘制前翻转纵向位置
        let flipped = CGRect(
            x: rect.minX,
            y: extent.height - rect.maxY,
            width: rect.width,
            height: rect.height
        )
        let image = UIGraphicsImageRenderer(size: canvas, format: format).image { ctx in
            ctx.cgContext.setFillColor(UIColor.white.cgColor)
            UIBezierPath(
                roundedRect: flipped,
                cornerRadius: CGFloat(min(flipped.width, flipped.height) * 2 * cornerRadius)
            ).fill()
        }
        guard let cg = image.cgImage else { return black }
        return CIImage(cgImage: cg).composited(over: black)
    }

    // MARK: - 彩虹渐变（256×1 横向七色，按需缩放）

    private static let rainbowGradient: CIImage? = {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: CGSize(width: 256, height: 1), format: format).image { ctx in
            let colors = [
                UIColor(red: 1, green: 0.2, blue: 0.2, alpha: 1),
                UIColor(red: 1, green: 0.6, blue: 0.1, alpha: 1),
                UIColor(red: 1, green: 0.9, blue: 0.2, alpha: 1),
                UIColor(red: 0.25, green: 0.8, blue: 0.35, alpha: 1),
                UIColor(red: 0.2, green: 0.75, blue: 0.9, alpha: 1),
                UIColor(red: 0.25, green: 0.4, blue: 1, alpha: 1),
                UIColor(red: 0.7, green: 0.3, blue: 0.9, alpha: 1),
            ].map(\.cgColor) as CFArray
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: nil
            ) else { return }
            ctx.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: 256, y: 0),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
        }
        guard let cg = image.cgImage else { return nil }
        return CIImage(cgImage: cg)
    }()
}

/// 拉伸铺满 extent 并绕中心旋转 45°（彩虹条的对角走向）
private extension CIImage {
    func rotatedDiagonal(extent: CGRect) -> CIImage {
        let scaleX = extent.width / max(self.extent.width, 1)
        let scaleY = extent.height / max(self.extent.height, 1)
        let stretched = transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        let angle = CGFloat.pi / 4
        let center = CGPoint(x: extent.midX, y: extent.midY)
        let rotation = CGAffineTransform(translationX: center.x, y: center.y)
            .rotated(by: angle)
            .translatedBy(x: -center.x, y: -center.y)
        return stretched.transformed(by: rotation).cropped(to: extent)
    }
}

/// 水印与表情：先用 UIKit 画一个小贴片，再用 CIAffineTile 无限平铺。
enum TextTiler {
    static func watermarkTile(
        text: String,
        fontSize: CGFloat,
        angleDegrees: Double,
        opacity: Double,
        lineSpacing: Double,
        extent: CGRect
    ) -> CIImage? {
        guard !text.isEmpty else { return nil }
        let font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white,
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let tileW = max(ceil(textSize.width * 1.8), 8)
        let tileH = max(ceil(fontSize * 1.6 * max(lineSpacing, 1)), 8)

        let tile = renderTile(width: tileW, height: tileH) { size in
            (text as NSString).draw(
                at: CGPoint(x: (size.width - textSize.width) / 2, y: (size.height - textSize.height) / 2),
                withAttributes: attributes
            )
        }
        guard var tiled = CIImage(image: tile) else { return nil }
        tiled = tiled.applyingFilter("CIAffineTile")

        // CI y 轴向上，角度取负得到与 UIKit 直觉一致的顺时针
        let radians = -CGFloat(angleDegrees) * .pi / 180
        let center = CGPoint(x: extent.midX, y: extent.midY)
        let rotation = CGAffineTransform(translationX: center.x, y: center.y)
            .rotated(by: radians)
            .translatedBy(x: -center.x, y: -center.y)
        tiled = tiled.transformed(by: rotation).cropped(to: extent)

        return tiled.applyingFilter("CIColorMatrix", parameters: [
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: CGFloat(opacity)),
        ])
    }

    static func emojiTile(emoji: String, blockRect: CGRect, extent: CGRect) -> CIImage? {
        guard !emoji.isEmpty, blockRect.width > 0, blockRect.height > 0 else { return nil }
        let fontSize = max(min(blockRect.width, blockRect.height) * 0.6, 8)
        let font = UIFont.systemFont(ofSize: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let glyphSize = (emoji as NSString).size(withAttributes: attributes)
        let tileW = ceil(glyphSize.width * 1.2)
        let tileH = ceil(glyphSize.height * 1.2)

        let tile = renderTile(width: tileW, height: tileH) { size in
            (emoji as NSString).draw(
                at: CGPoint(x: (size.width - glyphSize.width) / 2, y: (size.height - glyphSize.height) / 2),
                withAttributes: attributes
            )
        }
        guard let ci = CIImage(image: tile) else { return nil }
        return ci.applyingFilter("CIAffineTile").cropped(to: extent)
    }

    private static func renderTile(
        width: CGFloat,
        height: CGFloat,
        draw: (CGSize) -> Void
    ) -> UIImage {
        let size = CGSize(width: max(width, 2), height: max(height, 2))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(size)
        }
    }
}
