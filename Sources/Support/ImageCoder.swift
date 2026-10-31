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
}
