import UIKit

enum ImageCoder {
    /// 把 EXIF 方向烘焙进像素，强制朝上。
    /// 之后所有坐标与渲染都基于该结果，不再处理方向。
    static func normalized(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let size = CGSize(width: image.size.width, height: image.size.height)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// 降采样（预览用），等比缩到最长边 ≤ maxDimension
    static func downscaled(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let maxSide = max(image.size.width, image.size.height)
        guard maxSide > maxDimension, maxSide > 0 else { return image }
        let ratio = maxDimension / maxSide
        let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// 重新编码天然剥离 EXIF/GPS 等元数据（只写像素，不拷贝旧属性）
    static func jpegData(_ image: UIImage, quality: CGFloat = 0.92) -> Data? {
        image.jpegData(compressionQuality: quality)
    }

    static func pngData(_ image: UIImage) -> Data? {
        image.pngData()
    }

    /// "隐藏文字"工具：在 rect 周边采样背景主色（要求纯色背景）。
    /// 把 rect 外扩一倍的环形区域缩到 48×48 位图，跳过中心半区（即文字本体），
    /// 对剩余像素做量化直方图取众数，返回该桶的平均色。
    static func dominantBackground(near rect: CGRect, in image: UIImage) -> RGBA {
        guard let cg = image.cgImage else { return .ink }
        let pxW = CGFloat(cg.width)
        let pxH = CGFloat(cg.height)
        let pixelRect = CGRect(
            x: rect.minX * pxW,
            y: (1 - rect.maxY) * pxH,
            width: rect.width * pxW,
            height: rect.height * pxH
        )
        let expanded = pixelRect
            .insetBy(dx: -pixelRect.width * 0.5, dy: -pixelRect.height * 0.5)
            .intersection(CGRect(x: 0, y: 0, width: pxW, height: pxH))
        guard expanded.width >= 4, expanded.height >= 4 else { return .ink }

        let sample = 48
        guard let ctx = CGContext(
            data: nil,
            width: sample,
            height: sample,
            bitsPerComponent: 8,
            bytesPerRow: sample * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return .ink }
        ctx.interpolationQuality = .low
        let sx = CGFloat(sample) / expanded.width
        let sy = CGFloat(sample) / expanded.height
        // 把原图整体画进来，使 expanded 区域恰好铺满 48×48 画布
        ctx.draw(cg, in: CGRect(
            x: -expanded.minX * sx,
            y: -(pxH - expanded.maxY) * sy,
            width: pxW * sx,
            height: pxH * sy
        ))
        guard let data = ctx.data else { return .ink }
        let pixels = data.bindMemory(to: UInt8.self, capacity: sample * sample * 4)

        // 中央半区是文字本体，跳过；直方图量化到 5 级/通道
        var counts: [UInt16: Int] = [:]
        var sums: [UInt16: (r: Int, g: Int, b: Int)] = [:]
        for y in 0..<sample {
            for x in 0..<sample {
                if (12..<36).contains(x), (12..<36).contains(y) { continue }
                let offset = (y * sample + x) * 4
                let r = Int(pixels[offset])
                let g = Int(pixels[offset + 1])
                let b = Int(pixels[offset + 2])
                let key = UInt16((r / 32) << 10 | (g / 32) << 5 | (b / 32))
                counts[key, default: 0] += 1
                sums[key, default: (0, 0, 0)].r += r
                sums[key, default: (0, 0, 0)].g += g
                sums[key, default: (0, 0, 0)].b += b
            }
        }
        guard let (bestKey, bestCount) = counts.max(by: { $0.value < $1.value }), bestCount > 0,
              let sum = sums[bestKey] else { return .ink }
        return RGBA(
            red: Double(sum.r) / Double(bestCount) / 255,
            green: Double(sum.g) / Double(bestCount) / 255,
            blue: Double(sum.b) / Double(bestCount) / 255,
            alpha: 1
        )
    }
}
